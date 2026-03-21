import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 本地通知服务
/// 
/// 用于在收到新消息时显示系统通知横幅
/// 支持前台和后台状态的通知声音播放
/// 
/// 后台声音原理：
/// - 使用 Importance.max 和 Priority.max 确保系统优先处理
/// - 使用系统默认声音，由系统负责播放
/// - 设置 category 为 message ，标记为即时通信类型
class LocalNotificationService {
  static final LocalNotificationService _instance = LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  // 通知频道配置 - 使用新的频道ID确保声音设置生效
  static const String _channelId = 'chat_messages_v2';
  static const String _channelName = '聊天消息';
  static const String _channelDescription = '新消息通知（含声音）';

  /// 初始化通知服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Android 初始化设置
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      
      // iOS 初始化设置
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      // 创建 Android 通知频道（启用声音和振动）
      if (Platform.isAndroid) {
        final androidPlugin = _notifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        
        if (androidPlugin != null) {
          // 删除旧频道（如果存在），确保新配置生效
          await androidPlugin.deleteNotificationChannel('chat_messages');
          
          // 创建新频道，使用最高优先级和系统默认声音
          const channel = AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.max, // 最高优先级，确保后台也能播放
            playSound: true,
            enableVibration: true,
            showBadge: true,
            enableLights: true,
            // 使用系统默认声音（不指定 sound 属性，让系统使用默认通知声）
          );

          await androidPlugin.createNotificationChannel(channel);

          // 创建后台服务通知渠道（低优先级，用于前台服务）
          // 必须在启动后台服务之前创建
          const backgroundChannel = AndroidNotificationChannel(
            'sec_chat_background',
            'SecChat后台服务',
            description: '保持消息连接活跃',
            importance: Importance.low,
            playSound: false,
            enableVibration: false,
            showBadge: false,
          );

          await androidPlugin.createNotificationChannel(backgroundChannel);
          
          // 请求通知权限（Android 13+）- 延迟请求避免启动时崩溃
          Future.delayed(const Duration(seconds: 1), () async {
            try {
              await androidPlugin.requestNotificationsPermission();
            } catch (e) {
              print('Request notification permission error: $e');
            }
          });
        }
      }

      _isInitialized = true;
      print('LocalNotificationService initialized with channel: $_channelId');
    } catch (e) {
      print('LocalNotificationService initialize error: $e');
    }
  }

  /// 显示消息通知
  /// 
  /// 后台时系统会自动播放默认通知声音
  Future<void> showMessageNotification({
    required String senderName,
    required String messageContent,
    required String roomId,
    String? messageId,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Android 通知详情（后台时系统自动播放声音）
      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.max,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        // 设置头像占位符
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        // 确保通知会在状态栏、锁屏和后台显示
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.message,
        // 设置样式
        styleInformation: BigTextStyleInformation(
          messageContent,
          contentTitle: senderName,
          summaryText: '新消息',
        ),
        // 后台通知配置
        fullScreenIntent: false,
        channelShowBadge: true,
        autoCancel: true,
        // 通知分组（用于通知堆叠）
        groupKey: 'chat_messages_group',
      );

      // iOS 通知详情
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        sound: 'default', // 使用系统默认声音
        interruptionLevel: InterruptionLevel.timeSensitive, // 时间敏感通知
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      // 使用时间戳作为通知ID，确保每条消息都是独立通知
      final notificationId = DateTime.now().millisecondsSinceEpoch.remainder(100000);

      await _notifications.show(
        notificationId,
        senderName,
        messageContent,
        details,
        payload: '$roomId|$messageId',
      );
      
      print('Notification shown: $senderName - $messageContent');
    } catch (e) {
      print('Show notification error: $e');
    }
  }

  /// 通知点击回调
  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) {
      // payload 格式: "roomId|messageId"
      final parts = payload.split('|');
      if (parts.isNotEmpty) {
        final roomId = parts[0];
        // TODO: 导航到对应的聊天室
        print('Notification tapped, roomId: $roomId');
      }
    }
  }

  /// 清除所有通知
  Future<void> clearAll() async {
    await _notifications.cancelAll();
  }

  /// 清除指定房间的通知
  Future<void> clearRoomNotifications(int notificationId) async {
    await _notifications.cancel(notificationId);
  }
}

/// 全局本地通知服务实例
final localNotificationService = LocalNotificationService();
