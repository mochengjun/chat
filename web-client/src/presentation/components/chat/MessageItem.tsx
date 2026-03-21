import { memo, useCallback } from 'react';
import { Avatar, Typography, Tooltip, Dropdown } from 'antd';
import type { MenuProps } from 'antd';
import {
  UserOutlined,
  CheckOutlined,
  CopyOutlined,
  FileOutlined,
  PlayCircleOutlined,
} from '@ant-design/icons';
import type { Message } from '@domain/entities/Message';
import AuthImage from './AuthImage';
import dayjs from 'dayjs';

const { Text, Paragraph } = Typography;

interface MessageItemProps {
  message: Message;
  currentUserId: string;
  onCopyMessage: (content: string) => void;
  onPreviewImage: (url: string) => void;
}

// 格式化消息时间
const formatMessageTime = (date: Date) => {
  return dayjs(date).format('HH:mm');
};

// 检查是否需要显示日期分隔符
export const shouldShowDateSeparator = (currentMsg: Message, prevMsg?: Message) => {
  if (!prevMsg) return true;
  return !dayjs(currentMsg.createdAt).isSame(prevMsg.createdAt, 'day');
};

// 格式化日期分隔符
export const formatDateSeparator = (date: Date) => {
  const today = dayjs();
  const msgDate = dayjs(date);
  
  if (msgDate.isSame(today, 'day')) {
    return '今天';
  } else if (msgDate.isSame(today.subtract(1, 'day'), 'day')) {
    return '昨天';
  } else if (msgDate.isSame(today, 'year')) {
    return msgDate.format('M月D日');
  } else {
    return msgDate.format('YYYY年M月D日');
  }
};

// 使用 memo 优化消息项渲染
export const MessageItem = memo(function MessageItem({
  message,
  currentUserId,
  onCopyMessage,
  onPreviewImage,
}: MessageItemProps) {
  const isOwnMessage = message.senderId === currentUserId;

  // 右键菜单项
  const menuItems: MenuProps['items'] = [
    {
      key: 'copy',
      label: '复制',
      icon: <CopyOutlined />,
      onClick: () => onCopyMessage(message.content),
    },
  ];

  // 渲染消息内容
  const renderContent = useCallback(() => {
    switch (message.type) {
      case 'image':
        return (
          <div style={{ cursor: 'pointer' }}>
            <AuthImage
              src={message.mediaUrl}
              alt={message.content || '图片'}
              onClick={() => message.mediaUrl && onPreviewImage(message.mediaUrl)}
            />
            {message.content && (
              <Paragraph style={{
                margin: '4px 0 0 0',
                fontSize: 12,
                color: isOwnMessage ? 'rgba(255,255,255,0.8)' : '#666',
              }}>
                {message.content}
              </Paragraph>
            )}
          </div>
        );
      case 'file':
        return (
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <FileOutlined style={{ fontSize: 24 }} />
            <div>
              <Text strong>{message.content}</Text>
              {message.mediaSize && (
                <Text type="secondary" style={{ fontSize: 12, display: 'block' }}>
                  {(message.mediaSize / 1024).toFixed(2)} KB
                </Text>
              )}
            </div>
          </div>
        );
      case 'video':
        return (
          <div style={{ cursor: 'pointer' }}>
            <PlayCircleOutlined style={{ fontSize: 48, color: '#667eea' }} />
            <Text style={{ display: 'block', marginTop: 8 }}>{message.content}</Text>
          </div>
        );
      default:
        return (
          <Paragraph style={{
            margin: 0,
            whiteSpace: 'pre-wrap',
            wordBreak: 'break-word',
          }}>
            {message.content}
          </Paragraph>
        );
    }
  }, [message, isOwnMessage, onPreviewImage]);

  return (
    <Dropdown menu={{ items: menuItems }} trigger={['contextMenu']}>
      <div
        style={{
          display: 'flex',
          justifyContent: isOwnMessage ? 'flex-end' : 'flex-start',
          marginBottom: 12,
        }}
      >
        {!isOwnMessage && (
          <Avatar
            size={36}
            icon={<UserOutlined />}
            style={{ marginRight: 8, flexShrink: 0 }}
          >
            {message.sender?.displayName?.[0] || message.sender?.username?.[0]}
          </Avatar>
        )}
        
        <div style={{ maxWidth: '70%' }}>
          {!isOwnMessage && (
            <Text type="secondary" style={{ fontSize: 12, display: 'block', marginBottom: 2 }}>
              {message.sender?.displayName || message.sender?.username}
            </Text>
          )}
          
          <div
            style={{
              padding: '8px 12px',
              borderRadius: 8,
              backgroundColor: isOwnMessage ? '#667eea' : '#f0f0f0',
              color: isOwnMessage ? 'white' : 'black',
            }}
          >
            {renderContent()}
          </div>
          
          <div style={{ display: 'flex', alignItems: 'center', gap: 4, marginTop: 2 }}>
            <Tooltip title={dayjs(message.createdAt).format('YYYY-MM-DD HH:mm:ss')}>
              <Text type="secondary" style={{ fontSize: 11 }}>
                {formatMessageTime(message.createdAt)}
              </Text>
            </Tooltip>
            {isOwnMessage && message.readBy && message.readBy.length > 0 && (
              <CheckOutlined style={{ fontSize: 12, color: '#52c41a' }} />
            )}
          </div>
        </div>
      </div>
    </Dropdown>
  );
}, (prevProps, nextProps) => {
  // 自定义比较函数，只在关键 props 变化时重新渲染
  return (
    prevProps.message.id === nextProps.message.id &&
    prevProps.message.content === nextProps.message.content &&
    prevProps.message.readBy?.length === nextProps.message.readBy?.length &&
    prevProps.currentUserId === nextProps.currentUserId
  );
});
