import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_constants.dart';

/// 后台服务管理器
/// 
/// 使用Android前台服务保持应用在后台活跃，确保：
/// - WebSocket连接不被系统暂停
/// - 后台能正常接收和处理消息
/// - 后台能播放系统通知声音
class BackgroundServiceManager {
  static final BackgroundServiceManager _instance = BackgroundServiceManager._internal();
  factory BackgroundServiceManager() => _instance;
  BackgroundServiceManager._internal();

  bool _isInitialized = false;
  final FlutterBackgroundService _service = FlutterBackgroundService();

  /// 初始化后台服务
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // 仅在Android上启用前台服务
    if (!Platform.isAndroid) {
      _isInitialized = true;
      return;
    }

    try {
      // 配置后台服务（添加超时保护）
      // 注意：autoStart 设为 false，手动控制启动时机，避免启动时崩溃
      await _service.configure(
        androidConfiguration: AndroidConfiguration(
          onStart: _onStart,
          autoStart: false,
          autoStartOnBoot: true,
          isForegroundMode: true,
          // 前台服务通知配置
          notificationChannelId: 'sec_chat_background',
          initialNotificationTitle: 'SecChat',
          initialNotificationContent: '保持消息连接中...',
          foregroundServiceNotificationId: 888,
          foregroundServiceTypes: [AndroidForegroundType.dataSync],
        ),
        iosConfiguration: IosConfiguration(
          autoStart: false,
          onForeground: _onStart,
          onBackground: _onIosBackground,
        ),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('BackgroundServiceManager configure timeout');
          return false; // 超时返回 false
        },
      );

      _isInitialized = true;
      print('BackgroundServiceManager initialized');
      
      // 异步请求电池优化豁免（不阻塞）
      _requestBatteryOptimizationExemption();
    } catch (e) {
      print('BackgroundServiceManager initialize error: $e');
      // 即使失败也标记为已初始化，避免重复尝试
      _isInitialized = true;
    }
  }

  /// 启动后台服务
  Future<void> startService() async {
    if (!_isInitialized) {
      await initialize();
    }
    
    if (Platform.isAndroid) {
      final isRunning = await _service.isRunning();
      if (!isRunning) {
        await _service.startService();
        print('Background service started');
      }
    }
  }

  /// 停止后台服务
  Future<void> stopService() async {
    if (Platform.isAndroid) {
      final isRunning = await _service.isRunning();
      if (isRunning) {
        _service.invoke('stopService');
        print('Background service stopped');
      }
    }
  }

  /// 检查服务是否运行中
  Future<bool> isRunning() async {
    if (Platform.isAndroid) {
      return await _service.isRunning();
    }
    return false;
  }

  /// 通知后台服务显示消息通知
  void notifyNewMessage({
    required String title,
    required String body,
    required String roomId,
    String? messageId,
  }) {
    if (Platform.isAndroid) {
      _service.invoke('showNotification', {
        'title': title,
        'body': body,
        'roomId': roomId,
        'messageId': messageId,
      });
    }
  }

  /// 更新后台服务状态通知
  void updateServiceNotification(String content) {
    if (Platform.isAndroid) {
      _service.invoke('updateNotification', {'content': content});
    }
  }

  /// 请求电池优化豁免
  /// 
  /// 使用原生Android Intent方式，比permission_handler更稳定
  /// 异步执行，不阻塞主流程，延迟5秒后请求避免启动时崩溃
  Future<void> _requestBatteryOptimizationExemption() async {
    if (!Platform.isAndroid) return;
    
    // 延迟5秒后执行，避免应用启动时立即弹窗导致崩溃
    Future.delayed(const Duration(seconds: 5), () async {
      try {
        const platform = MethodChannel('sec_chat/battery_optimization');
        
        // 添加超时保护，避免无限等待
        final isIgnoring = await platform
            .invokeMethod<bool>('isIgnoringBatteryOptimizations')
            .timeout(
              const Duration(seconds: 3),
              onTimeout: () => true, // 超时时假设已豁免，不弹窗
            );
        
        if (isIgnoring != true) {
          // 再次延迟2秒，确保应用已完全启动并处于前台
          await Future.delayed(const Duration(seconds: 2));
          try {
            await platform.invokeMethod('requestIgnoreBatteryOptimizations');
            print('Battery optimization exemption requested');
          } catch (e) {
            print('Request battery optimization error: $e');
          }
        } else {
          print('Battery optimization already exempted or skipped');
        }
      } catch (e) {
        // MethodChannel未实现时静默失败，不影响应用运行
        print('Battery optimization check skipped: $e');
      }
    });
  }
}

/// 后台服务入口点 (Android)
/// 
/// 注意：此函数在后台隔离中运行，需要遵循以下规则：
/// 1. 使用 @pragma('vm:entry-point') 保持函数不被树摇优化
/// 2. 使用 DartPluginRegistrant.ensureInitialized() 初始化插件
/// 3. 避免使用需要在主隔离中初始化的插件
/// 4. 保持最小化操作，避免崩溃
@pragma('vm:entry-point')
Future<void> _onStart(ServiceInstance service) async {
  // 仅使用 DartPluginRegistrant，不使用 WidgetsFlutterBinding
  // 这可以避免某些插件在后台隔离中的初始化问题
  DartPluginRegistrant.ensureInitialized();

  // 初始化后台通知服务
  final backgroundNotificationService = _BackgroundNotificationService();
  await backgroundNotificationService.initialize();

  // 设置为前台服务
  if (service is AndroidServiceInstance) {
    try {
      service.setAsForegroundService();
    } catch (e) {
      print('Background service setAsForegroundService error: $e');
    }
    
    // 监听前台/后台状态变化
    service.on('setAsForeground').listen((event) {
      try {
        service.setAsForegroundService();
      } catch (e) {
        print('setAsForeground error: $e');
      }
    });
    
    service.on('setAsBackground').listen((event) {
      try {
        service.setAsBackgroundService();
      } catch (e) {
        print('setAsBackground error: $e');
      }
    });
  }

  // 监听停止服务命令
  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // 监听更新通知命令
  service.on('updateNotification').listen((event) {
    if (service is AndroidServiceInstance) {
      try {
        final content = event?['content'] as String? ?? '保持消息连接中...';
        service.setForegroundNotificationInfo(
          title: 'SecChat',
          content: content,
        );
      } catch (e) {
        print('updateNotification error: $e');
      }
    }
  });

  // 监听显示消息通知命令
  service.on('showNotification').listen((event) async {
    final title = event?['title'] as String? ?? '新消息';
    final body = event?['body'] as String? ?? '';
    final roomId = event?['roomId'] as String? ?? '';
    final messageId = event?['messageId'] as String?;
    
    print('Background received notification request: $title - $body (roomId: $roomId)');
    
    // 在后台隔离中显示通知
    await backgroundNotificationService.showMessageNotification(
      title: title,
      body: body,
      roomId: roomId,
      messageId: messageId,
    );
  });

  // 心跳计时器 - 保持服务活跃并打印日志
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    if (service is AndroidServiceInstance) {
      try {
        if (await service.isForegroundService()) {
          print('Background service heartbeat - service is running');
        }
      } catch (e) {
        print('Heartbeat check error: $e');
      }
    }
  });
  
  print('Background service _onStart completed');
}

/// iOS后台处理
@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

/// 后台通知服务
/// 
/// 用于在后台隔离中显示通知
/// 注意：此类运行在独立的Dart隔离中，不能访问主隔离的状态
class _BackgroundNotificationService {
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  
  /// 通知ID计数器
  int _notificationIdCounter = NotificationConstants.backgroundNotificationIdMin;

  /// 初始化通知服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Android 初始化设置
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

      const initSettings = InitializationSettings(
        android: androidSettings,
      );

      await _notifications.initialize(initSettings);

      // 创建 Android 通知频道
      if (Platform.isAndroid) {
        await _createNotificationChannel();
      }

      _isInitialized = true;
      print('_BackgroundNotificationService initialized');
    } catch (e) {
      print('_BackgroundNotificationService initialize error: $e');
    }
  }

  /// 创建通知频道
  Future<void> _createNotificationChannel() async {
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    
    if (androidPlugin == null) return;

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
  }

  /// 生成唯一的通知ID
  int _generateNotificationId() {
    _notificationIdCounter++;
    if (_notificationIdCounter > NotificationConstants.backgroundNotificationIdMax) {
      _notificationIdCounter = NotificationConstants.backgroundNotificationIdMin;
    }
    return _notificationIdCounter;
  }

  /// 显示消息通知
  Future<bool> showMessageNotification({
    required String title,
    required String body,
    required String roomId,
    String? messageId,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (!_isInitialized) {
      print('_BackgroundNotificationService not initialized, cannot show notification');
      return false;
    }

    try {
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

      final details = NotificationDetails(android: androidDetails);

      // 使用确定性通知ID实现跨通道去重
      final notificationId = (messageId != null && messageId.isNotEmpty)
          ? NotificationConstants.messageIdToNotificationId(messageId)
          : _generateNotificationId();

      // 构建payload: type|roomId|messageId
      final payload = '${NotificationConstants.payloadTypeLocal}'
          '${NotificationConstants.payloadSeparator}$roomId'
          '${NotificationConstants.payloadSeparator}${messageId ?? ""}';

      await _notifications.show(
        notificationId,
        title,
        body,
        details,
        payload: payload,
      );
      
      print('Background notification shown: $title - $body');
      return true;
    } catch (e) {
      print('Show background notification error: $e');
      return false;
    }
  }
}

/// 全局后台服务管理器实例
final backgroundServiceManager = BackgroundServiceManager();
