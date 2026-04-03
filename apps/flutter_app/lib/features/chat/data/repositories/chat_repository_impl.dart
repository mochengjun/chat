import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../domain/entities/room.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/member.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/chat_repository.dart';
import '../datasources/chat_remote_datasource.dart';
import '../datasources/chat_local_datasource.dart';
import '../../../../core/network/websocket_client.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/services/media_service.dart';
import '../../../../core/services/notification_sound_service.dart';
import '../../../../core/services/local_notification_service.dart';
import '../../../../core/services/notification_constants.dart';
import '../../../../core/security/secure_storage.dart';

class ChatRepositoryImpl implements ChatRepository {
  final ChatRemoteDataSource _remoteDataSource;
  final ChatLocalDataSource _localDataSource;
  final WebSocketClient _webSocketClient;

  final _messageStreamController = StreamController<Message>.broadcast();
  final _roomUpdateStreamController = StreamController<Room>.broadcast();
  final _readReceiptStreamController = StreamController<Map<String, dynamic>>.broadcast();
  
  // 缓存当前用户ID，避免每次都读取存储
  String? _cachedCurrentUserId;
  
  /// 当前打开的房间ID（用于判断是否需要显示通知）
  String? _currentOpenRoomId;

  ChatRepositoryImpl({
    required ChatRemoteDataSource remoteDataSource,
    required ChatLocalDataSource localDataSource,
    required WebSocketClient webSocketClient,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource,
        _webSocketClient = webSocketClient {
    _setupWebSocketListeners();
  }

  /// 设置当前打开的房间（用于控制通知显示）
  void setCurrentOpenRoom(String? roomId) {
    _currentOpenRoomId = roomId;
    if (roomId != null) {
      // 进入房间时清除该房间的通知缓存
      notificationCache.clearRoomMessages(roomId);
    }
  }

  /// 播放消息提示音并显示通知（非自己发送的消息）
  /// 
  /// 功能特性：
  /// - 消息去重
  /// - 通知节流
  /// - 通知合并
  /// - 当前打开的房间不显示通知
  Future<void> _handleNewMessageNotification(Message message) async {
    try {
      // 获取当前用户ID（优先使用缓存）
      if (_cachedCurrentUserId == null) {
        final secureStorage = getIt<SecureStorageService>();
        final userInfo = await secureStorage.getUserInfo();
        _cachedCurrentUserId = userInfo['userId'];
      }
      
      // 检查是否是自己发送的消息
      final isOwnMessage = _cachedCurrentUserId != null && 
                           message.senderId == _cachedCurrentUserId;
      
      // 检查是否是当前打开的房间
      final isCurrentRoom = _currentOpenRoomId == message.roomId;
      
      // 自己的消息或当前打开的房间不显示通知
      if (isOwnMessage || isCurrentRoom) {
        debugPrint('Skip notification: ownMessage=$isOwnMessage, currentRoom=$isCurrentRoom');
        return;
      }

      final senderName = message.senderName.isNotEmpty ? message.senderName : '新消息';
      final content = _getNotificationContent(message);

      // 尝试播放自定义提示音（前台时有效）
      try {
        await notificationSoundService.playMessageSound();
      } catch (e) {
        debugPrint('Custom notification sound failed: $e');
      }

      // 显示系统通知（带节流和去重）
      final shown = await localNotificationService.showMessageNotification(
        senderName: senderName,
        messageContent: content,
        roomId: message.roomId,
        messageId: message.id,
      );

      // 本地通知已由 localNotificationService 显示
      // 不再通过 backgroundServiceManager 重复显示，避免同一消息产生双重通知
      if (shown) {
        debugPrint('Notification shown for message: ${message.id}');
      }
    } catch (e) {
      debugPrint('Handle notification error: $e');
    }
  }
  
  /// 获取通知内容
  String _getNotificationContent(Message message) {
    switch (message.type) {
      case MessageType.image:
        return '[图片]';
      case MessageType.video:
        return '[视频]';
      case MessageType.audio:
        return '[语音]';
      case MessageType.file:
        return '[文件]';
      default:
        return message.content.isNotEmpty ? message.content : '新消息';
    }
  }

  void _setupWebSocketListeners() {
    _webSocketClient.messageStream.listen((data) async {
      if (data['type'] == 'new_message') {
        final message = _parseMessage(data['payload']);
        _messageStreamController.add(message);
        _localDataSource.cacheMessage(message);
        
        // 处理新消息通知（带节流和去重）
        await _handleNewMessageNotification(message);
      } else if (data['type'] == 'message_deleted') {
        // 处理消息删除事件
        final payload = data['payload'] as Map<String, dynamic>;
        final messageId = payload['message_id'] as String;
        final roomId = payload['room_id'] as String;
        _localDataSource.deleteMessage(messageId);
        // 通过流通知消息已被删除
        final deletedMessage = Message(
          id: messageId,
          roomId: roomId,
          senderId: '',
          senderName: '',
          content: '',
          isDeleted: true,
          createdAt: DateTime.now(),
        );
        _messageStreamController.add(deletedMessage);
      } else if (data['type'] == 'room_update') {
        final room = _parseRoom(data['payload']);
        _roomUpdateStreamController.add(room);
      } else if (data['type'] == 'read_receipt') {
        // 处理已读回执事件
        final payload = data['payload'] as Map<String, dynamic>;
        _readReceiptStreamController.add(payload);
      }
    });
  }

  Message _parseMessage(Map<String, dynamic> data) {
    return Message(
      id: data['id'],
      roomId: data['room_id'],
      senderId: data['sender_id'],
      senderName: data['sender_name'] ?? '',
      senderAvatar: data['sender_avatar'],
      content: data['content'] ?? '',
      type: _parseMessageType(data['type']),
      status: MessageStatus.sent,
      mediaUrl: data['media_url'],
      thumbnailUrl: data['thumbnail_url'],
      mediaSize: data['media_size'],
      mimeType: data['mime_type'],
      createdAt: data['created_at'] != null 
          ? DateTime.parse(data['created_at']) 
          : DateTime.now(),
      autoDeleteAfter: data['auto_delete_after'],
      autoDeleteAt: data['auto_delete_at'] != null 
          ? DateTime.parse(data['auto_delete_at']) 
          : null,
    );
  }

  Room _parseRoom(Map<String, dynamic> data) {
    return Room(
      id: data['id'],
      name: data['name'] ?? '',
      unreadCount: data['unread_count'] ?? 0,
      createdAt: data['created_at'] != null 
          ? DateTime.parse(data['created_at']) 
          : DateTime.now(),
    );
  }

  MessageType _parseMessageType(String? type) {
    switch (type) {
      case 'image': return MessageType.image;
      case 'video': return MessageType.video;
      case 'audio': return MessageType.audio;
      case 'file': return MessageType.file;
      case 'system': return MessageType.system;
      default: return MessageType.text;
    }
  }

  @override
  Future<List<Room>> getRooms() async {
    try {
      final rooms = await _remoteDataSource.getRooms();
      await _localDataSource.cacheRooms(rooms);
      return rooms;
    } catch (_) {
      return await _localDataSource.getCachedRooms();
    }
  }

  @override
  Future<Room> getRoom(String roomId) async {
    return await _remoteDataSource.getRoom(roomId);
  }

  @override
  Future<Room> createRoom({
    required String name,
    String? description,
    RoomType type = RoomType.group,
    List<String>? memberIds,
    int? retentionHours,
  }) async {
    final room = await _remoteDataSource.createRoom(
      name: name,
      description: description,
      type: type,
      memberIds: memberIds,
      retentionHours: retentionHours,
    );
    await _localDataSource.cacheRooms([room]);
    return room;
  }

  @override
  Future<Room> updateRoom({
    required String roomId,
    String? name,
    String? description,
    String? avatarUrl,
    int? retentionHours,
  }) async {
    return await _remoteDataSource.updateRoom(
      roomId: roomId,
      name: name,
      description: description,
      avatarUrl: avatarUrl,
      retentionHours: retentionHours,
    );
  }

  @override
  Future<void> leaveRoom(String roomId) async {
    await _remoteDataSource.leaveRoom(roomId);
    await _localDataSource.clearRoomMessages(roomId);
  }

  @override
  Future<List<Message>> getMessages({
    required String roomId,
    int limit = 50,
    String? beforeId,
  }) async {
    try {
      final messages = await _remoteDataSource.getMessages(
        roomId: roomId,
        limit: limit,
        beforeId: beforeId,
      );
      await _localDataSource.cacheMessages(messages);
      return messages;
    } catch (_) {
      return await _localDataSource.getCachedMessages(roomId, limit: limit);
    }
  }

  @override
  Future<Message> sendMessage({
    required String roomId,
    required String content,
    MessageType type = MessageType.text,
    String? mediaUrl,
    String? thumbnailUrl,
    int? mediaSize,
    String? mimeType,
    Map<String, dynamic>? metadata,
    int? autoDeleteAfter,
  }) async {
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempMessage = Message(
      id: tempId,
      roomId: roomId,
      senderId: '',
      senderName: '',
      content: content,
      type: type,
      status: MessageStatus.sending,
      mediaUrl: mediaUrl,
      thumbnailUrl: thumbnailUrl,
      mediaSize: mediaSize,
      mimeType: mimeType,
      createdAt: DateTime.now(),
      autoDeleteAfter: autoDeleteAfter,
    );
    
    _messageStreamController.add(tempMessage);
    await _localDataSource.cacheMessage(tempMessage);

    try {
      final message = await _remoteDataSource.sendMessage(
        roomId: roomId,
        content: content,
        type: type,
        mediaUrl: mediaUrl,
        thumbnailUrl: thumbnailUrl,
        mediaSize: mediaSize,
        mimeType: mimeType,
        metadata: metadata,
        autoDeleteAfter: autoDeleteAfter,
      );
      
      await _localDataSource.deleteMessage(tempId);
      await _localDataSource.cacheMessage(message);
      
      return message;
    } catch (e) {
      final failedMessage = tempMessage.copyWith(status: MessageStatus.failed);
      await _localDataSource.updateMessageStatus(tempId, 'failed');
      _messageStreamController.add(failedMessage);
      rethrow;
    }
  }

  @override
  Future<Message> sendMediaMessage({
    required String roomId,
    required String filePath,
    required MessageType type,
    String? caption,
  }) async {
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final file = File(filePath);
    final fileName = file.path.split('/').last;
    
    final tempMessage = Message(
      id: tempId,
      roomId: roomId,
      senderId: '',
      senderName: '',
      content: caption ?? fileName,
      type: type,
      status: MessageStatus.sending,
      createdAt: DateTime.now(),
    );
    
    _messageStreamController.add(tempMessage);
    await _localDataSource.cacheMessage(tempMessage);

    try {
      // 上传文件
      final mediaService = getIt<MediaService>();
      final mediaInfo = await mediaService.upload(file, roomId: roomId);
      
      // 发送媒体消息 - 直接发送媒体字段
      final message = await _remoteDataSource.sendMessage(
        roomId: roomId,
        content: caption ?? mediaInfo.originalName,
        type: type,
        mediaUrl: mediaInfo.downloadUrl,
        thumbnailUrl: mediaInfo.thumbnailUrl,
        mediaSize: mediaInfo.size,
        mimeType: mediaInfo.mimeType,
      );
      
      await _localDataSource.deleteMessage(tempId);
      await _localDataSource.cacheMessage(message);
      
      return message;
    } catch (e) {
      final failedMessage = tempMessage.copyWith(status: MessageStatus.failed);
      await _localDataSource.updateMessageStatus(tempId, 'failed');
      _messageStreamController.add(failedMessage);
      rethrow;
    }
  }

  @override
  Future<void> markAsRead(String roomId, {String? messageId}) async {
    await _remoteDataSource.markAsRead(roomId, messageId: messageId);
  }

  @override
  Future<void> deleteMessage(String roomId, String messageId) async {
    await _remoteDataSource.deleteMessage(roomId, messageId);
    await _localDataSource.deleteMessage(messageId);
  }

  @override
  Future<List<Member>> getRoomMembers(String roomId) async {
    return await _remoteDataSource.getRoomMembers(roomId);
  }

  @override
  Future<void> addRoomMembers(String roomId, List<String> userIds) async {
    await _remoteDataSource.addRoomMembers(roomId, userIds);
  }

  @override
  Future<void> removeRoomMember(String roomId, String userId) async {
    await _remoteDataSource.removeRoomMember(roomId, userId);
  }

  @override
  Future<void> updateMemberRole(String roomId, String userId, MemberRole role) async {
    await _remoteDataSource.updateMemberRole(roomId, userId, role);
  }

  @override
  Future<void> muteRoom(String roomId, bool muted) async {
    await _remoteDataSource.muteRoom(roomId, muted);
  }

  @override
  Future<void> pinRoom(String roomId, bool pinned) async {
    await _remoteDataSource.pinRoom(roomId, pinned);
  }

  @override
  Future<List<User>> searchUsers(String query, {int limit = 20}) async {
    return await _remoteDataSource.searchUsers(query, limit: limit);
  }

  @override
  Stream<Message> get messageStream => _messageStreamController.stream;

  @override
  Stream<Room> get roomUpdateStream => _roomUpdateStreamController.stream;

  @override
  Stream<Map<String, dynamic>> get readReceiptStream => _readReceiptStreamController.stream;

  @override
  Future<void> connect() async {
    await _webSocketClient.connect();
  }

  @override
  Future<void> disconnect() async {
    await _webSocketClient.disconnect();
  }

  void dispose() {
    _messageStreamController.close();
    _roomUpdateStreamController.close();
    _readReceiptStreamController.close();
  }
}
