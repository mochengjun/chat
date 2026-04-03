import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dio/dio.dart';
import 'app_badge_service.dart';
import 'notification_constants.dart';
import 'global_navigation_service.dart';

/// 推送通知类型
enum PushNotificationType {
  newMessage,
  mention,
  roomInvite,
  systemAlert,
  callIncoming,
  callMissed,
}

/// 推送通知数据
class PushNotificationData {
  final String? type;
  final String? roomId;
  final String? messageId;
  final String? senderId;
  final Map<String, dynamic> extra;

  PushNotificationData({
    this.type,
    this.roomId,
    this.messageId,
    this.senderId,
    this.extra = const {},
  });

  factory PushNotificationData.fromMap(Map<String, dynamic> map) {
    return PushNotificationData(
      type: map['type'] as String?,
      roomId: map['room_id'] as String?,
      messageId: map['message_id'] as String?,
      senderId: map['sender_id'] as String?,
      extra: Map<String, dynamic>.from(map),
    );
  }
}

/// 推送设置
class PushSettings {
  final bool enablePush;
  final bool enableSound;
  final bool enableVibration;
  final bool enablePreview;
  final int? quietHoursStart;
  final int? quietHoursEnd;
  final List<String> mutedRooms;

  PushSettings({
    this.enablePush = true,
    this.enableSound = true,
    this.enableVibration = true,
    this.enablePreview = true,
    this.quietHoursStart,
    this.quietHoursEnd,
    this.mutedRooms = const [],
  });

  factory PushSettings.fromJson(Map<String, dynamic> json) {
    return PushSettings(
      enablePush: json['enable_push'] ?? true,
      enableSound: json['enable_sound'] ?? true,
      enableVibration: json['enable_vibration'] ?? true,
      enablePreview: json['enable_preview'] ?? true,
      quietHoursStart: json['quiet_hours_start'],
      quietHoursEnd: json['quiet_hours_end'],
      mutedRooms: json['muted_rooms'] != null
          ? List<String>.from(jsonDecode(json['muted_rooms']))
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enable_push': enablePush,
      'enable_sound': enableSound,
      'enable_vibration': enableVibration,
      'enable_preview': enablePreview,
      'quiet_hours_start': quietHoursStart,
      'quiet_hours_end': quietHoursEnd,
      'muted_rooms': jsonEncode(mutedRooms),
    };
  }

  PushSettings copyWith({
    bool? enablePush,
    bool? enableSound,
    bool? enableVibration,
    bool? enablePreview,
    int? quietHoursStart,
    int? quietHoursEnd,
    List<String>? mutedRooms,
  }) {
    return PushSettings(
      enablePush: enablePush ?? this.enablePush,
      enableSound: enableSound ?? this.enableSound,
      enableVibration: enableVibration ?? this.enableVibration,
      enablePreview: enablePreview ?? this.enablePreview,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      mutedRooms: mutedRooms ?? this.mutedRooms,
    );
  }
}

/// 推送通知服务
class PushNotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final Dio _dio;
  final String _baseUrl;

  // 通知回调
  Function(PushNotificationData)? onNotificationTap;
  Function(RemoteMessage)? onForegroundMessage;

  /// 通知ID计数器
  int _notificationIdCounter = NotificationConstants.fcmNotificationIdMin;

  PushNotificationService({
    required Dio dio,
    required String baseUrl,
  })  : _dio = dio,
        _baseUrl = baseUrl;

  /// 初始化推送服务
  Future<void> initialize() async {
    try {
      // 初始化本地通知（无需权限）
      await _initLocalNotifications();

      // 延迟请求权限和FCM配置，避免启动时弹窗导致崩溃
      Future.delayed(const Duration(seconds: 3), () async {
        try {
          // 请求权限
          final permissionGranted = await _requestPermission();
          if (!permissionGranted) {
            debugPrint('Push notification permission not granted');
          }

          // 配置 FCM 消息处理
          _configureMessageHandlers();

          // 获取并注册 token
          await _registerToken();

          // 监听 token 刷新
          _messaging.onTokenRefresh.listen(_onTokenRefresh);
        } catch (e) {
          debugPrint('Push notification delayed init error: $e');
        }
      });
    } catch (e) {
      debugPrint('Push notification initialize error: $e');
    }
  }

  /// 请求通知权限
  Future<bool> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    return settings.authorizationStatus == AuthorizationStatus.authorized;
  }

  /// 初始化本地通知
  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // 通知频道由 LocalNotificationService 统一创建，此处不再重复创建
  }

  /// 配置消息处理器
  void _configureMessageHandlers() {
    // 前台消息
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 后台/终止状态点击通知
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // 检查是否从通知启动
    _checkInitialMessage();
  }

  /// 检查初始消息（从通知启动应用）
  Future<void> _checkInitialMessage() async {
    final message = await _messaging.getInitialMessage();
    if (message != null) {
      _handleNotificationTap(message);
    }
  }

  /// 处理前台消息
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    onForegroundMessage?.call(message);

    // 显示本地通知
    final notification = message.notification;
    if (notification != null) {
      // 检查消息ID去重
      final messageId = message.data['message_id'] as String?;
      if (messageId != null && notificationCache.checkAndAddMessageId(messageId)) {
        debugPrint('FCM foreground duplicate skipped: $messageId');
        return;
      }
      
      // 检查节流（按房间）
      final roomId = message.data['room_id'] as String? ?? 'unknown';
      if (!notificationCache.shouldThrottle(roomId)) {
        await _showLocalNotification(
          title: notification.title ?? 'New Message',
          body: notification.body ?? '',
          roomId: roomId,
          messageId: messageId,
          payload: jsonEncode(message.data),
        );
      }
    }
  }

  /// 处理通知点击
  void _handleNotificationTap(RemoteMessage message) {
    final data = PushNotificationData.fromMap(message.data);
    
    // 默认导航行为：跳转到聊天室
    if (data.roomId != null) {
      GlobalNavigationService.navigateToRoom(data.roomId!);
    }
    
    // 调用外部回调
    onNotificationTap?.call(data);
  }

  /// 本地通知点击响应
  void _onNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;

    debugPrint('FCM notification tapped: $payload');

    try {
      // 尝试解析为JSON（FCM格式）
      try {
        final data = jsonDecode(payload) as Map<String, dynamic>;
        final notificationData = PushNotificationData.fromMap(data);
        
        // 默认导航行为
        if (notificationData.roomId != null) {
          GlobalNavigationService.navigateToRoom(notificationData.roomId!);
        }
        
        // 调用外部回调
        onNotificationTap?.call(notificationData);
      } catch (_) {
        // 尝试解析为本地通知格式: type|roomId|messageId
        final parts = payload.split(NotificationConstants.payloadSeparator);
        if (parts.length >= 2) {
          final roomId = parts[1];
          GlobalNavigationService.navigateToRoom(roomId);
        }
      }
    } catch (e) {
      debugPrint('Handle notification response error: $e');
    }
  }

  /// 生成唯一的通知ID
  int _generateNotificationId() {
    _notificationIdCounter++;
    if (_notificationIdCounter > NotificationConstants.fcmNotificationIdMax) {
      _notificationIdCounter = NotificationConstants.fcmNotificationIdMin;
    }
    return _notificationIdCounter;
  }

  /// 显示本地通知（支持前台和后台播放声音）
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? roomId,
    String? messageId,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      NotificationConstants.chatMessagesChannelId,
      NotificationConstants.chatMessagesChannelName,
      channelDescription: NotificationConstants.chatMessagesChannelDescription,
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.message,
      fullScreenIntent: false,
      channelShowBadge: true,
      autoCancel: true,
      groupKey: NotificationConstants.chatMessagesGroupKey,
    );

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

    // 生成唯一通知ID
    final notificationId = (messageId != null && messageId.isNotEmpty)
        ? NotificationConstants.messageIdToNotificationId(messageId)
        : _generateNotificationId();

    // 构建payload
    final finalPayload = payload ??
        '${NotificationConstants.payloadTypeFcm}'
        '${NotificationConstants.payloadSeparator}${roomId ?? ""}'
        '${NotificationConstants.payloadSeparator}${messageId ?? ""}';

    await _localNotifications.show(
      notificationId,
      title,
      body,
      details,
      payload: finalPayload,
    );
  }

  /// 获取并注册 FCM token
  Future<void> _registerToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _sendTokenToServer(token);
      }
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }
  }

  /// Token 刷新回调
  Future<void> _onTokenRefresh(String token) async {
    await _sendTokenToServer(token);
  }

  /// 发送 token 到服务器
  Future<void> _sendTokenToServer(String token) async {
    try {
      final deviceId = await _getDeviceId();
      final platform = Platform.isIOS ? 'apns' : 'fcm';

      await _dio.post(
        '$_baseUrl/push/token',
        data: {
          'device_id': deviceId,
          'platform': platform,
          'token': token,
        },
      );

      // 保存 token 到本地
      await _storage.write(key: 'push_token', value: token);
    } catch (e) {
      debugPrint('Error sending token to server: $e');
    }
  }

  /// 获取设备 ID
  Future<String> _getDeviceId() async {
    var deviceId = await _storage.read(key: 'device_id');
    if (deviceId == null) {
      deviceId = DateTime.now().millisecondsSinceEpoch.toString();
      await _storage.write(key: 'device_id', value: deviceId);
    }
    return deviceId;
  }

  /// 注销推送 token
  Future<void> unregisterToken() async {
    try {
      final token = await _storage.read(key: 'push_token');
      if (token != null) {
        await _dio.delete(
          '$_baseUrl/push/token',
          data: {'token': token},
        );
        await _storage.delete(key: 'push_token');
      }
    } catch (e) {
      debugPrint('Error unregistering token: $e');
    }
  }

  /// 获取推送设置
  Future<PushSettings> getSettings() async {
    try {
      final response = await _dio.get('$_baseUrl/push/settings');
      return PushSettings.fromJson(response.data);
    } catch (e) {
      return PushSettings();
    }
  }

  /// 更新推送设置
  Future<void> updateSettings(PushSettings settings) async {
    await _dio.put(
      '$_baseUrl/push/settings',
      data: settings.toJson(),
    );
  }

  /// 订阅房间主题
  Future<void> subscribeToRoom(String roomId) async {
    await _messaging.subscribeToTopic('room_$roomId');
  }

  /// 取消订阅房间主题
  Future<void> unsubscribeFromRoom(String roomId) async {
    await _messaging.unsubscribeFromTopic('room_$roomId');
  }

  /// 清除所有通知
  Future<void> clearAllNotifications() async {
    await _localNotifications.cancelAll();
  }

  /// 清除特定房间的通知
  Future<void> clearRoomNotifications(String roomId) async {
    notificationCache.clearRoomMessages(roomId);
  }

  /// 设置徽章数量 (iOS/Android)
  Future<void> setBadgeCount(int count) async {
    await appBadgeService.clearAll();
    if (count > 0) {
      // 由于服务是按房间管理的，这里简化处理
    }
  }
}

/// 后台消息处理器（必须是顶级函数）
/// 当应用在后台或被终止时，这个函数将处理收到的推送消息
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 确保 Firebase 已初始化
  await Firebase.initializeApp();
  
  debugPrint('Background message received: ${message.messageId}');

  // 初始化本地通知插件
  final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();
  
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings(
    requestSoundPermission: true,
    requestAlertPermission: true,
    requestBadgePermission: true,
  );
  const initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );
  
  await localNotifications.initialize(initSettings);

  // 确保通知频道已创建（使用统一的频道配置）
  if (Platform.isAndroid) {
    final channel = AndroidNotificationChannel(
      NotificationConstants.chatMessagesChannelId,
      NotificationConstants.chatMessagesChannelName,
      description: NotificationConstants.chatMessagesChannelDescription,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      showBadge: true,
    );

    await localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // 获取通知内容
  String title = message.notification?.title ?? '新消息';
  String body = message.notification?.body ?? '';
  String? roomId = message.data['room_id'];
  String? messageId = message.data['message_id'];
  
  // 如果是数据消息，从 data 中提取内容
  if (message.data.isNotEmpty) {
    title = message.data['title'] ?? title;
    body = message.data['body'] ?? message.data['message'] ?? body;
  }
  
  // 构建payload
  final payload = '${NotificationConstants.payloadTypeFcm}'
      '${NotificationConstants.payloadSeparator}${roomId ?? ""}'
      '${NotificationConstants.payloadSeparator}${messageId ?? ""}';

  // 显示本地通知
  final androidDetails = AndroidNotificationDetails(
    NotificationConstants.chatMessagesChannelId,
    NotificationConstants.chatMessagesChannelName,
    channelDescription: NotificationConstants.chatMessagesChannelDescription,
    importance: Importance.max,
    priority: Priority.max,
    showWhen: true,
    playSound: true,
    enableVibration: true,
    enableLights: true,
    largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
    visibility: NotificationVisibility.public,
    category: AndroidNotificationCategory.message,
    styleInformation: BigTextStyleInformation(
      body,
      contentTitle: title,
      summaryText: '新消息',
    ),
    fullScreenIntent: false,
    channelShowBadge: true,
    autoCancel: true,
    groupKey: NotificationConstants.chatMessagesGroupKey,
  );

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

  // 使用确定性通知ID实现跨通道去重
  final notificationId = (messageId != null && messageId.isNotEmpty)
      ? NotificationConstants.messageIdToNotificationId(messageId)
      : DateTime.now().millisecondsSinceEpoch % 
          (NotificationConstants.fcmNotificationIdMax - NotificationConstants.fcmNotificationIdMin) +
          NotificationConstants.fcmNotificationIdMin;

  await localNotifications.show(
    notificationId,
    title,
    body,
    details,
    payload: payload,
  );
  
  debugPrint('Background notification shown: $title');
}
