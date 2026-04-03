import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/services/media_service.dart';
import '../../../../core/security/secure_storage.dart';
import '../../domain/entities/message.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/usecases/get_messages_usecase.dart';
import '../../domain/usecases/send_message_usecase.dart';
import '../../domain/usecases/mark_as_read_usecase.dart';
import 'chat_room_event.dart';
import 'chat_room_state.dart';

class ChatRoomBloc extends Bloc<ChatRoomEvent, ChatRoomState> {
  final GetMessagesUseCase _getMessagesUseCase;
  final SendMessageUseCase _sendMessageUseCase;
  final MarkAsReadUseCase _markAsReadUseCase;
  final ChatRepository _repository;
  
  String? _currentRoomId;
  String? _currentUserId; // 当前用户 ID，用于已读回执处理
  StreamSubscription<Message>? _messageSubscription;
  StreamSubscription<Map<String, dynamic>>? _readReceiptSubscription;
  static const _pageSize = 50;

  ChatRoomBloc({
    required GetMessagesUseCase getMessagesUseCase,
    required SendMessageUseCase sendMessageUseCase,
    required MarkAsReadUseCase markAsReadUseCase,
    required ChatRepository repository,
  })  : _getMessagesUseCase = getMessagesUseCase,
        _sendMessageUseCase = sendMessageUseCase,
        _markAsReadUseCase = markAsReadUseCase,
        _repository = repository,
        super(const ChatRoomInitial()) {
    on<LoadMessages>(_onLoadMessages);
    on<LoadMoreMessages>(_onLoadMoreMessages);
    on<SendTextMessage>(_onSendTextMessage);
    on<SendMediaMessage>(_onSendMediaMessage);
    on<NewMessageReceived>(_onNewMessageReceived);
    on<MarkMessagesRead>(_onMarkMessagesRead);
    on<DeleteMessage>(_onDeleteMessage);
    on<RetryMessage>(_onRetryMessage);
    on<ReadReceiptReceived>(_onReadReceiptReceived);

    _messageSubscription = _repository.messageStream.listen((message) {
      if (message.roomId == _currentRoomId) {
        add(NewMessageReceived(message));
      }
    }, onError: (error) {
      // 忽略流错误，避免 bloc 崩溃
    }, cancelOnError: false);
    
    // 监听已读回执事件
    _readReceiptSubscription = _repository.readReceiptStream.listen((data) {
      final roomId = data['room_id'] as String?;
      final userId = data['user_id'] as String?;
      final readAtStr = data['read_at'] as String?;
      
      if (roomId == _currentRoomId && userId != null && readAtStr != null) {
        add(ReadReceiptReceived(
          roomId: roomId!,
          userId: userId,
          readAt: DateTime.parse(readAtStr),
        ));
      }
    }, onError: (error) {
      // 忽略流错误，避免 bloc 崩溃
    }, cancelOnError: false);
  }

  Future<void> _onLoadMessages(
    LoadMessages event,
    Emitter<ChatRoomState> emit,
  ) async {
    _currentRoomId = event.roomId;
    emit(const ChatRoomLoading());
    
    try {
      // 获取当前用户 ID
      if (_currentUserId == null) {
        final storage = getIt<SecureStorageService>();
        final userInfo = await storage.getUserInfo();
        _currentUserId = userInfo['userId'];
      }
      
      final messages = await _getMessagesUseCase(
        roomId: event.roomId,
        limit: _pageSize,
      );
      
      final room = await _repository.getRoom(event.roomId);
      
      // 按时间正序排序（最旧的在前，最新的在后）
      final sortedMessages = List<Message>.from(messages)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      emit(ChatRoomLoaded(
        room: room,
        messages: sortedMessages,
        hasMoreMessages: messages.length >= _pageSize,
      ));
      
      add(const MarkMessagesRead());
    } catch (e) {
      emit(ChatRoomError(message: e.toString()));
    }
  }

  Future<void> _onLoadMoreMessages(
    LoadMoreMessages event,
    Emitter<ChatRoomState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ChatRoomLoaded ||
        currentState.isLoadingMore ||
        !currentState.hasMoreMessages ||
        _currentRoomId == null) {
      return;
    }
    
    emit(currentState.copyWith(isLoadingMore: true));
    
    try {
      final oldestMessage = currentState.messages.isNotEmpty
          ? currentState.messages.first
          : null;
      
      final messages = await _getMessagesUseCase(
        roomId: _currentRoomId!,
        limit: _pageSize,
        beforeId: oldestMessage?.id,
      );
      
      // 合并消息并按时间正序排序
      final updatedMessages = [...messages, ...currentState.messages]
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      emit(currentState.copyWith(
        messages: updatedMessages,
        isLoadingMore: false,
        hasMoreMessages: messages.length >= _pageSize,
      ));
    } catch (e) {
      emit(currentState.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onSendTextMessage(
    SendTextMessage event,
    Emitter<ChatRoomState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ChatRoomLoaded || _currentRoomId == null) {
      return;
    }
    
    // 创建临时消息并立即显示
    final tempMessage = Message(
      id: 'temp_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(99999)}',
      roomId: _currentRoomId!,
      senderId: 'current_user_id', // 当前用户ID
      senderName: '我',
      content: event.content,
      type: MessageType.text,
      status: MessageStatus.sending,
      createdAt: DateTime.now(),
    );
    
    // 立即将临时消息添加到列表末尾并更新UI
    final messagesWithTemp = [...currentState.messages, tempMessage];
    emit(currentState.copyWith(
      messages: messagesWithTemp,
      isSending: true,
      sendingError: null,
    ));
    
    try {
      // 发送消息并获取服务器返回的真实消息
      final sentMessage = await _sendMessageUseCase(
        roomId: _currentRoomId!,
        content: event.content,
        type: MessageType.text,
      );
      
      // 发送成功，直接用服务器返回的消息替换临时消息
      // 设置状态为 sent（已发送）
      final confirmedMessage = sentMessage.copyWith(status: MessageStatus.sent);
      final updatedMessages = messagesWithTemp.map((m) {
        if (m.id == tempMessage.id) {
          return confirmedMessage;
        }
        return m;
      }).toList();
      
      emit(currentState.copyWith(
        messages: updatedMessages,
        isSending: false,
      ));
    } catch (e) {
      // 发送失败，更新临时消息状态为失败
      final failedMessage = tempMessage.copyWith(status: MessageStatus.failed);
      final updatedMessages = messagesWithTemp.map((m) {
        if (m.id == tempMessage.id) {
          return failedMessage;
        }
        return m;
      }).toList();
      
      emit(currentState.copyWith(
        messages: updatedMessages,
        isSending: false,
        sendingError: e.toString(),
      ));
    }
  }

  Future<void> _onSendMediaMessage(
    SendMediaMessage event,
    Emitter<ChatRoomState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ChatRoomLoaded || _currentRoomId == null) {
      return;
    }

    // 创建临时消息
    final tempMessage = Message(
      id: 'temp_${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(99999)}',
      roomId: _currentRoomId!,
      senderId: 'current_user_id',
      senderName: '我',
      content: event.caption ?? '发送文件中...',
      type: event.type,
      status: MessageStatus.sending,
      createdAt: DateTime.now(),
    );

    // 立即显示临时消息
    final messagesWithTemp = [...currentState.messages, tempMessage];
    emit(currentState.copyWith(
      messages: messagesWithTemp,
      isSending: true,
      sendingError: null,
    ));

    try {
      // 上传文件
      final mediaService = getIt<MediaService>();
      final file = File(event.filePath);
      final mediaInfo = await mediaService.upload(
        file,
        roomId: _currentRoomId!,
      );

      // 发送媒体消息 - 获取返回的真实消息
      final sentMessage = await _sendMessageUseCase(
        roomId: _currentRoomId!,
        content: mediaInfo.originalName,
        type: event.type,
        mediaUrl: mediaInfo.downloadUrl,
        thumbnailUrl: mediaInfo.thumbnailUrl,
        mediaSize: mediaInfo.size,
        mimeType: mediaInfo.mimeType,
      );

      // 用真实消息替换临时消息
      final updatedMessages = messagesWithTemp.map((m) {
        if (m.id == tempMessage.id) return sentMessage;
        return m;
      }).toList();

      emit(currentState.copyWith(
        messages: updatedMessages,
        isSending: false,
      ));
    } catch (e) {
      // 发送失败，更新临时消息状态
      final failedMessage = tempMessage.copyWith(status: MessageStatus.failed);
      final updatedMessages = messagesWithTemp.map((m) {
        if (m.id == tempMessage.id) return failedMessage;
        return m;
      }).toList();

      emit(currentState.copyWith(
        messages: updatedMessages,
        isSending: false,
        sendingError: e.toString(),
      ));
    }
  }

  void _onNewMessageReceived(
    NewMessageReceived event,
    Emitter<ChatRoomState> emit,
  ) {
    final currentState = state;
    if (currentState is! ChatRoomLoaded) return;
    
    final existingIndex = currentState.messages
        .indexWhere((m) => m.id == event.message.id);
    
    List<Message> updatedMessages;
    if (existingIndex != -1) {
      // 已存在相同ID的消息，更新它
      updatedMessages = List.from(currentState.messages);
      updatedMessages[existingIndex] = event.message;
    } else {
      // 移除所有相关的临时消息（可能有多条）
      updatedMessages = currentState.messages.where((m) {
        // 保留非临时消息
        if (!m.id.startsWith('temp_')) return true;
        // 保留非 sending 状态的临时消息
        if (m.status != MessageStatus.sending) return true;
        // 移除匹配内容的临时消息
        if (m.content == event.message.content) return false;
        // 移除 "发送文件中..." 占位消息
        if (m.content == '发送文件中...') return false;
        return true;
      }).toList();
      
      // 添加新消息
      updatedMessages.add(event.message);
    }
    
    // 按时间正序排序
    updatedMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    
    emit(currentState.copyWith(messages: updatedMessages));
  }

  Future<void> _onMarkMessagesRead(
    MarkMessagesRead event,
    Emitter<ChatRoomState> emit,
  ) async {
    if (_currentRoomId == null) return;
    
    try {
      await _markAsReadUseCase(_currentRoomId!);
    } catch (_) {}
  }

  Future<void> _onDeleteMessage(
    DeleteMessage event,
    Emitter<ChatRoomState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ChatRoomLoaded || _currentRoomId == null) {
      return;
    }
    
    try {
      await _repository.deleteMessage(_currentRoomId!, event.messageId);
      
      final updatedMessages = currentState.messages
          .where((m) => m.id != event.messageId)
          .toList();
      
      emit(currentState.copyWith(messages: updatedMessages));
    } catch (e) {
      emit(currentState.copyWith(sendingError: '删除失败: ${e.toString()}'));
    }
  }

  Future<void> _onRetryMessage(
    RetryMessage event,
    Emitter<ChatRoomState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ChatRoomLoaded || _currentRoomId == null) {
      return;
    }
    
    final updatedMessages = currentState.messages
        .where((m) => m.id != event.messageId)
        .toList();
    emit(currentState.copyWith(messages: updatedMessages));
    
    add(SendTextMessage(event.content));
  }

  /// 处理已读回执事件
  void _onReadReceiptReceived(
    ReadReceiptReceived event,
    Emitter<ChatRoomState> emit,
  ) {
    final currentState = state;
    if (currentState is! ChatRoomLoaded) return;
      
    // 更新所有由当前用户发送的消息状态为"已读"
    // 注意：只更新当前用户发送的消息，且在对方阅读时间之前发送的
    final updatedMessages = currentState.messages.map((m) {
      // 只更新当前用户发送的消息
      if (m.senderId != _currentUserId) {
        return m;
      }
        
      // 跳过已经是已读状态的消息
      if (m.status == MessageStatus.read) {
        return m;
      }
        
      // 如果消息创建时间在对方阅读时间之前或相同，标记为已读
      if (m.createdAt.isBefore(event.readAt) || m.createdAt.isAtSameMomentAs(event.readAt)) {
        return m.copyWith(status: MessageStatus.read);
      }
        
      // 否则标记为已送达（对方在线但还未阅读这条消息）
      if (m.status == MessageStatus.sent) {
        return m.copyWith(status: MessageStatus.delivered);
      }
        
      return m;
    }).toList();
      
    emit(currentState.copyWith(messages: updatedMessages));
  }

  @override
  Future<void> close() {
    _messageSubscription?.cancel();
    _readReceiptSubscription?.cancel();
    return super.close();
  }
}
