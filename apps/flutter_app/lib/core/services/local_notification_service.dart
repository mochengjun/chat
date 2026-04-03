import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'notification_constants.dart';
import 'global_navigation_service.dart';

/// 本地通知服务
/// 
/// 用于在收到新消息时显示系统通知横幅
/// 支持前台和后台状态的通知声音播放
/// 
/// 功能特性：
/// - 通知节流控制
/// - 消息去重
/// - 通知合并（同一房间多条消息）
/// - 通知点击导航
class LocalNotificationService {
  static final LocalNotificationService _instance = LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  
  /// 通知ID计数器
  int _notificationIdCounter = NotificationConstants.messageNotificationIdMin;

  /// 权限请求结果回调
  Function(bool granted)? onPermissionResult;

  /// 初始化通知服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Android 初始化设置
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      
      // iOS 初始化设置 - 延迟请求权限避免启动卡顿
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      // 创建 Android 通知频道
      if (Platform.isAndroid) {
        await _createNotificationChannels();
      }

      _isInitialized = true;
      debugPrint('LocalNotificationService initialized');
    } catch (e) {
      debugPrint('LocalNotificationService initialize error: $e');
    }
  }

  /// 创建通知频道
  Future<void> _createNotificationChannels() async {
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin == null) return;

    // 删除旧频道
    await androidPlugin.deleteNotificationChannel('chat_messages');

    // 创建聊天消息频道
    final chatChannel = AndroidNotificationChannel(
      NotificationConstants.chatMessagesChannelId,
      NotificationConstants.chatMessagesChannelName,
      description: NotificationConstants.chatMessagesChannelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
      enableLights: true,
    );
    await androidPlugin.createNotificationChannel(chatChannel);

    // 创建后台服务频道
    final backgroundChannel = AndroidNotificationChannel(
      NotificationConstants.backgroundServiceChannelId,
      NotificationConstants.backgroundServiceChannelName,
      description: NotificationConstants.backgroundServiceChannelDescription,
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
      showBadge: false,
    );
    await androidPlugin.createNotificationChannel(backgroundChannel);

    // 创建badge频道
    final badgeChannel = AndroidNotificationChannel(
      NotificationConstants.badgeChannelId,
      '未读消息角标',
      description: '用于显示桌面图标上的未读消息数',
      importance: Importance.min,
      playSound: false,
      enableVibration: false,
      showBadge: true,
    );
    await androidPlugin.createNotificationChannel(badgeChannel);

    // 延迟请求权限
    _requestPermissionWithRetry(androidPlugin);
  }

  /// 带重试的权限请求
  Future<bool> _requestPermissionWithRetry(
    AndroidFlutterLocalNotificationsPlugin androidPlugin,
  ) async {
    await Future.delayed(const Duration(seconds: 2));
    
    try {
      final granted = await androidPlugin.requestNotificationsPermission();
      final isGranted = granted ?? false;
      if (!isGranted) {
        debugPrint('Notification permission not granted');
      }
      // 通知上层UI权限结果
      onPermissionResult?.call(isGranted);
      return isGranted;
    } catch (e) {
      debugPrint('Request notification permission error: $e');
      onPermissionResult?.call(false);
      return false;
    }
  }

  /// 生成唯一的通知ID
  int _generateNotificationId() {
    _notificationIdCounter++;
    if (_notificationIdCounter > NotificationConstants.messageNotificationIdMax) {
      _notificationIdCounter = NotificationConstants.messageNotificationIdMin;
    }
    return _notificationIdCounter;
  }

  /// 显示消息通知
  /// 
  /// [senderName] 发送者名称
  /// [messageContent] 消息内容
  /// [roomId] 房间ID
  /// [messageId] 消息ID（可选，用于去重）
  /// 
  /// 返回是否成功显示通知
  Future<bool> showMessageNotification({
    required String senderName,
    required String messageContent,
    required String roomId,
    String? messageId,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // 检查是否为重复消息
    if (messageId != null && notificationCache.checkAndAddMessageId(messageId)) {
      debugPrint('Duplicate notification skipped: $messageId');
      return false;
    }

    // 节流控制
    if (notificationCache.shouldThrottle(roomId)) {
      debugPrint('Notification throttled');
      return false;
    }

    try {
      // 截断超长内容
      final truncatedContent = messageContent.length > NotificationConstants.maxNotificationContentLength
          ? '${messageContent.substring(0, NotificationConstants.maxNotificationContentLength)}...'
          : messageContent;

      // 缓存消息用于通知合并
      if (messageId != null) {
        notificationCache.addRoomMessage(roomId, NotificationMessage(
          messageId: messageId,
          senderName: senderName,
          content: truncatedContent,
          timestamp: DateTime.now(),
        ));
      }

      // 获取房间消息列表用于通知合并
      final roomMessages = notificationCache.getRoomMessages(roomId);
      final hasMultipleMessages = roomMessages.length > 1;

      // Android 通知详情
      final androidDetails = AndroidNotificationDetails(
        NotificationConstants.chatMessagesChannelId,
        NotificationConstants.chatMessagesChannelName,
        channelDescription: NotificationConstants.chatMessagesChannelDescription,
        importance: Importance.max,
        priority: Priority.max,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.message,
        // 根据消息数量选择不同的样式
        styleInformation: hasMultipleMessages
            ? InboxStyleInformation(
                roomMessages
                    .take(NotificationConstants.maxMergedMessages)
                    .map((m) => '${m.senderName}: ${m.content}')
                    .toList(),
                contentTitle: '$senderName (${roomMessages.length}条新消息)',
                summaryText: '新消息',
              )
            : BigTextStyleInformation(
                truncatedContent,
                contentTitle: senderName,
                summaryText: '新消息',
              ),
        fullScreenIntent: false,
        channelShowBadge: true,
        autoCancel: true,
        groupKey: NotificationConstants.chatMessagesGroupKey,
      );

      // iOS 通知详情
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default',
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // 生成通知ID：有messageId时使用确定性ID（跨通道去重），否则使用递增ID
      final notificationId = messageId != null
          ? NotificationConstants.messageIdToNotificationId(messageId)
          : _generateNotificationId();

      // 构建payload: JSON格式
      final payload = jsonEncode({
        'type': NotificationConstants.payloadTypeLocal,
        'roomId': roomId,
        'messageId': messageId ?? '',
      });

      // 通知标题和内容
      final title = hasMultipleMessages 
          ? '$senderName (${roomMessages.length}条新消息)' 
          : senderName;
      final body = hasMultipleMessages
          ? '${roomMessages.last.senderName}: ${roomMessages.last.content}'
          : truncatedContent;

      await _notifications.show(
        notificationId,
        title,
        body,
        details,
        payload: payload,
      );
      
      debugPrint('Notification shown: $title - $body');
      return true;
    } catch (e) {
      debugPrint('Show notification error: $e');
      return false;
    }
  }

  /// 通知点击回调
  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;

    debugPrint('Notification tapped, payload: $payload');

    try {
      // 优先尝试 JSON 格式解析
      try {
        final data = jsonDecode(payload) as Map<String, dynamic>;
        final roomId = data['roomId'] as String?;
        if (roomId != null && roomId.isNotEmpty) {
          _navigateToChatRoom(roomId);
          notificationCache.clearRoomMessages(roomId);
        }
        return;
      } catch (_) {}

      // 兼容旧的分隔符格式: type|roomId|messageId
      final parts = payload.split(NotificationConstants.payloadSeparator);
      if (parts.length >= 2) {
        final roomId = parts[1];
        if (roomId.isNotEmpty) {
          _navigateToChatRoom(roomId);
          notificationCache.clearRoomMessages(roomId);
        }
      }
    } catch (e) {
      debugPrint('Handle notification tap error: $e');
    }
  }

  /// 导航到聊天室
  void _navigateToChatRoom(String roomId) {
    GlobalNavigationService.navigateToRoom(roomId);
    debugPrint('Navigate to chat room requested: $roomId');
  }

  /// 清除所有通知
  Future<void> clearAll() async {
    await _notifications.cancelAll();
    notificationCache.clearAll();
  }

  /// 清除指定房间的通知
  Future<void> clearRoomNotifications(int notificationId) async {
    await _notifications.cancel(notificationId);
  }

  /// 检查通知权限是否已授予
  Future<bool> hasPermission() async {
    if (Platform.isAndroid) {
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      // Android 13+ 需要运行时权限
      return await androidPlugin?.areNotificationsEnabled() ?? false;
    }
    return true;
  }
}

/// 全局本地通知服务实例
final localNotificationService = LocalNotificationService();
