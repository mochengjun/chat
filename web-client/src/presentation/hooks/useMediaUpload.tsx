import { useState, useCallback } from 'react';
import { Upload, message, Progress } from 'antd';
import type { UploadFile, RcFile } from 'antd/es/upload/interface';
import { apiClient } from '@core/api/client';
import { ENDPOINTS } from '@core/api/endpoints';
import type { MediaUploadResponse } from '@shared/types/api.types';

interface UseMediaUploadOptions {
  maxSize?: number; // 最大文件大小（MB）
  acceptTypes?: string[]; // 允许的文件类型
  onSuccess?: (media: MediaUploadResponse) => void;
  onError?: (error: Error) => void;
}

interface UploadSession {
  sessionId: string;
  fileName: string;
  fileSize: number;
  totalChunks: number;
  uploadedChunks: number[];
  status: 'pending' | 'uploading' | 'paused' | 'completed' | 'failed';
}

interface UseMediaUploadReturn {
  uploading: boolean;
  progress: number;
  uploadFile: (file: RcFile) => Promise<MediaUploadResponse | null>;
  fileList: UploadFile[];
  setFileList: React.Dispatch<React.SetStateAction<UploadFile[]>>;
  clearFiles: () => void;
  pauseUpload: () => void;
  resumeUpload: (file: RcFile, sessionId: string) => Promise<MediaUploadResponse | null>;
  currentSession: UploadSession | null;
}

const CHUNK_SIZE = 5 * 1024 * 1024; // 5MB分片大小
const MAX_CONCURRENT_CHUNKS = 3; // 并发上传分片数

// 本地存储键
const UPLOAD_SESSIONS_KEY = 'upload_sessions';

// 保存上传会话到本地
function saveUploadSession(session: UploadSession) {
  try {
    const sessions = JSON.parse(localStorage.getItem(UPLOAD_SESSIONS_KEY) || '{}');
    sessions[session.sessionId] = session;
    localStorage.setItem(UPLOAD_SESSIONS_KEY, JSON.stringify(sessions));
  } catch (e) {
    console.error('Failed to save upload session:', e);
  }
}

// 删除上传会话
function removeUploadSession(sessionId: string) {
  try {
    const sessions = JSON.parse(localStorage.getItem(UPLOAD_SESSIONS_KEY) || '{}');
    delete sessions[sessionId];
    localStorage.setItem(UPLOAD_SESSIONS_KEY, JSON.stringify(sessions));
  } catch (e) {
    console.error('Failed to remove upload session:', e);
  }
}

export function useMediaUpload(options: UseMediaUploadOptions = {}): UseMediaUploadReturn {
  const {
    maxSize = 100, // 默认100MB
    acceptTypes = ['image/*', 'video/*', 'audio/*', 'application/pdf', '.doc', '.docx', '.xls', '.xlsx'],
    onSuccess,
    onError,
  } = options;

  const [uploading, setUploading] = useState(false);
  const [progress, setProgress] = useState(0);
  const [fileList, setFileList] = useState<UploadFile[]>([]);
  const [currentSession, setCurrentSession] = useState<UploadSession | null>(null);
  const [isPaused, setIsPaused] = useState(false);

  // 验证文件
  const validateFile = useCallback((file: RcFile): boolean => {
    // 检查文件大小
    const isLt = file.size / 1024 / 1024 < maxSize;
    if (!isLt) {
      message.error(`文件大小不能超过 ${maxSize}MB`);
      return false;
    }

    // 检查文件类型
    const isValidType = acceptTypes.some(type => {
      if (type.startsWith('.')) {
        return file.name.toLowerCase().endsWith(type.toLowerCase());
      }
      if (type.endsWith('/*')) {
        const baseType = type.replace('/*', '');
        return file.type.startsWith(baseType);
      }
      return file.type === type;
    });

    if (!isValidType) {
      message.error('不支持的文件类型');
      return false;
    }

    return true;
  }, [maxSize, acceptTypes]);

  // 普通上传（小文件）
  const uploadSmallFile = async (file: RcFile): Promise<MediaUploadResponse> => {
    const formData = new FormData();
    formData.append('file', file);

    const response = await apiClient.post<MediaUploadResponse>(
      ENDPOINTS.MEDIA.UPLOAD,
      formData,
      {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
        onUploadProgress: (progressEvent) => {
          if (progressEvent.total) {
            const percent = Math.round((progressEvent.loaded * 100) / progressEvent.total);
            setProgress(percent);
          }
        },
      }
    );

    return response.data;
  };

  // 上传单个分片（带重试）
  const uploadChunkWithRetry = async (
    sessionId: string,
    chunkIndex: number,
    chunk: Blob,
    maxRetries: number = 3
  ): Promise<void> => {
    let lastError: Error | null = null;
    
    for (let attempt = 0; attempt < maxRetries; attempt++) {
      try {
        const chunkFormData = new FormData();
        chunkFormData.append('chunk', chunk);
        
        await apiClient.post(
          ENDPOINTS.MEDIA.CHUNKED_CHUNK(sessionId, chunkIndex),
          chunkFormData,
          {
            headers: {
              'Content-Type': 'multipart/form-data',
            },
          }
        );
        return; // 成功则返回
      } catch (error) {
        lastError = error instanceof Error ? error : new Error('上传失败');
        if (attempt < maxRetries - 1) {
          // 等待一段时间后重试
          await new Promise(resolve => setTimeout(resolve, 1000 * (attempt + 1)));
        }
      }
    }
    
    throw lastError;
  };

  // 分片上传（大文件）- 带断点续传
  const uploadLargeFile = async (
    file: RcFile,
    existingSessionId?: string
  ): Promise<MediaUploadResponse> => {
    const totalChunks = Math.ceil(file.size / CHUNK_SIZE);
    let sessionId: string;
    let uploadedChunks: number[] = [];
    
    // 如果有现有会话，尝试恢复
    if (existingSessionId) {
      try {
        const statusResponse = await apiClient.get<{
          session_id: string;
          status: string;
          uploaded_chunks: number[];
          total_chunks: number;
        }>(ENDPOINTS.MEDIA.CHUNKED_STATUS(existingSessionId));
        
        if (statusResponse.data.status === 'pending' || statusResponse.data.status === 'uploading') {
          sessionId = existingSessionId;
          uploadedChunks = statusResponse.data.uploaded_chunks;
          message.info(`恢复上传，已完成 ${uploadedChunks.length}/${totalChunks} 分片`);
        } else {
          // 会话已失效，创建新会话
          existingSessionId = undefined;
        }
      } catch {
        // 会话不存在或已过期，创建新会话
        existingSessionId = undefined;
      }
    }
    
    // 创建新会话
    if (!existingSessionId) {
      const initResponse = await apiClient.post<{ session_id: string }>(
        ENDPOINTS.MEDIA.CHUNKED_INIT,
        {
          filename: file.name,
          size: file.size,
          mime_type: file.type,
          total_chunks: totalChunks,
        }
      );
      sessionId = initResponse.data.session_id;
    }
    
    // 初始化会话状态
    const session: UploadSession = {
      sessionId: sessionId!,
      fileName: file.name,
      fileSize: file.size,
      totalChunks,
      uploadedChunks,
      status: 'uploading',
    };
    setCurrentSession(session);
    saveUploadSession(session);
    
    // 计算待上传的分片
    const pendingChunks: number[] = [];
    for (let i = 0; i < totalChunks; i++) {
      if (!uploadedChunks.includes(i)) {
        pendingChunks.push(i);
      }
    }
    
    // 并发上传分片
    let completedChunks = uploadedChunks.length;
    const uploadChunk = async (chunkIndex: number) => {
      if (isPaused) {
        throw new Error('上传已暂停');
      }
      
      const start = chunkIndex * CHUNK_SIZE;
      const end = Math.min(start + CHUNK_SIZE, file.size);
      const chunk = file.slice(start, end);
      
      await uploadChunkWithRetry(sessionId!, chunkIndex, chunk);
      
      completedChunks++;
      const currentProgress = Math.round((completedChunks / totalChunks) * 100);
      setProgress(currentProgress);
      
      // 更新会话状态
      session.uploadedChunks = [...session.uploadedChunks, chunkIndex];
      saveUploadSession(session);
    };
    
    // 使用并发控制上传
    const chunkQueue = [...pendingChunks];
    const activeUploads: Promise<void>[] = [];
    
    while (chunkQueue.length > 0 || activeUploads.length > 0) {
      if (isPaused) {
        // 暂停时等待当前上传完成
        await Promise.allSettled(activeUploads);
        session.status = 'paused';
        saveUploadSession(session);
        throw new Error('上传已暂停');
      }
      
      // 启动新的上传
      while (activeUploads.length < MAX_CONCURRENT_CHUNKS && chunkQueue.length > 0) {
        const chunkIndex = chunkQueue.shift()!;
        const uploadPromise = uploadChunk(chunkIndex).then(() => {
          const index = activeUploads.indexOf(uploadPromise);
          if (index > -1) {
            activeUploads.splice(index, 1);
          }
        });
        activeUploads.push(uploadPromise);
      }
      
      // 等待任意一个上传完成
      if (activeUploads.length > 0) {
        await Promise.race(activeUploads);
      }
    }
    
    // 完成上传
    const completeResponse = await apiClient.post<MediaUploadResponse>(
      ENDPOINTS.MEDIA.CHUNKED_COMPLETE(sessionId!)
    );
    
    // 清理会话
    removeUploadSession(sessionId!);
    setCurrentSession(null);
    
    return completeResponse.data;
  };

  // 暂停上传
  const pauseUpload = useCallback(() => {
    setIsPaused(true);
    if (currentSession) {
      const session = { ...currentSession, status: 'paused' as const };
      setCurrentSession(session);
      saveUploadSession(session);
      message.info('上传已暂停');
    }
  }, [currentSession]);

  // 恢复上传
  const resumeUpload = useCallback(async (
    file: RcFile,
    sessionId: string
  ): Promise<MediaUploadResponse | null> => {
    setIsPaused(false);
    setUploading(true);
    
    try {
      const result = await uploadLargeFile(file, sessionId);
      message.success('文件上传成功');
      onSuccess?.(result);
      return result;
    } catch (error) {
      const err = error instanceof Error ? error : new Error('上传失败');
      if (err.message !== '上传已暂停') {
        message.error(err.message);
        onError?.(err);
      }
      return null;
    } finally {
      setUploading(false);
    }
  }, [onSuccess, onError]);

  // 上传文件
  const uploadFile = useCallback(async (file: RcFile): Promise<MediaUploadResponse | null> => {
    if (!validateFile(file)) {
      return null;
    }

    setUploading(true);
    setProgress(0);
    setIsPaused(false);

    try {
      let result: MediaUploadResponse;
      
      // 大于10MB使用分片上传
      if (file.size > 10 * 1024 * 1024) {
        result = await uploadLargeFile(file);
      } else {
        result = await uploadSmallFile(file);
      }

      message.success('文件上传成功');
      onSuccess?.(result);
      return result;
    } catch (error) {
      const err = error instanceof Error ? error : new Error('上传失败');
      if (err.message !== '上传已暂停') {
        message.error(err.message);
        onError?.(err);
      }
      return null;
    } finally {
      setUploading(false);
      setProgress(0);
    }
  }, [validateFile, onSuccess, onError]);

  // 清除文件列表
  const clearFiles = useCallback(() => {
    setFileList([]);
    setProgress(0);
    setCurrentSession(null);
    setIsPaused(false);
  }, []);

  return {
    uploading,
    progress,
    uploadFile,
    fileList,
    setFileList,
    clearFiles,
    pauseUpload,
    resumeUpload,
    currentSession,
  };
}

// 媒体上传组件
interface MediaUploaderProps {
  onUploadSuccess?: (media: MediaUploadResponse) => void;
  accept?: string;
  maxSize?: number;
  children?: React.ReactNode;
}

export function MediaUploader({
  onUploadSuccess,
  accept = 'image/*,video/*,audio/*,.pdf,.doc,.docx',
  maxSize = 100,
  children,
}: MediaUploaderProps) {
  const { uploading, progress, uploadFile, fileList, setFileList } = useMediaUpload({
    maxSize,
    onSuccess: onUploadSuccess,
  });

  const handleBeforeUpload = async (file: RcFile) => {
    await uploadFile(file);
    return false; // 阻止默认上传行为
  };

  return (
    <Upload
      accept={accept}
      fileList={fileList}
      onChange={({ fileList: newFileList }) => setFileList(newFileList)}
      beforeUpload={handleBeforeUpload}
      showUploadList={false}
    >
      {children}
      {uploading && (
        <Progress
          percent={progress}
          size="small"
          style={{ marginTop: 8 }}
        />
      )}
    </Upload>
  );
}
