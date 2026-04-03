import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// 应用图标角标服务
///
/// 用于管理Android/iOS桌面图标上的未读消息计数角标
/// 使用 flutter_local_notifications 实现
/// 支持：
/// - 设置总未读数
/// - 增加/减少未读数
/// - 清除角标
/// - 按房间管理未读计数
class AppBadgeService {
  static final AppBadgeService _instance = AppBadgeService._internal();
  factory AppBadgeService() => _instance;
  AppBadgeService._internal();

  /// 房间未读计数映射
  final Map<String, int> _roomUnreadCounts = {};

  /// 总未读数
  int _totalUnreadCount = 0;

  /// 是否支持角标
  bool _isBadgeSupported = false;

  /// 是否已初始化
  bool _isInitialized = false;

  /// 通知插件实例
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  /// Badge 通知频道ID
  static const String _badgeChannelId = 'badge_channel';

  /// Badge 通知ID
  static const int _badgeNotificationId = 999999;

  /// 获取总未读数
  int get totalUnreadCount => _totalUnreadCount;

  /// 初始化服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 检查平台是否支持角标
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        _isBadgeSupported = true;

        // Android 上创建支持 badge 的通知频道
        if (Platform.isAndroid) {
          await _createBadgeChannel();
        }

        debugPrint('AppBadgeService: Badge supported = $_isBadgeSupported');
      } else {
        _isBadgeSupported = false;
        debugPrint('AppBadgeService: Platform does not support badge');
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('AppBadgeService initialize error: $e');
      _isBadgeSupported = false;
      _isInitialized = true;
    }
  }

  /// 创建 badge 通知频道 (Android)
  Future<void> _createBadgeChannel() async {
    try {
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        const channel = AndroidNotificationChannel(
          _badgeChannelId,
          '未读消息角标',
          description: '用于显示桌面图标上的未读消息数',
          importance: Importance.min,
          showBadge: true,
          playSound: false,
          enableVibration: false,
        );

        await androidPlugin.createNotificationChannel(channel);
      }
    } catch (e) {
      debugPrint('AppBadgeService create channel error: $e');
    }
  }

  /// 设置房间未读数
  ///
  /// [roomId] 房间ID
  /// [count] 未读消息数
  Future<void> setRoomUnreadCount(String roomId, int count) async {
    final oldCount = _roomUnreadCounts[roomId] ?? 0;
    _roomUnreadCounts[roomId] = count;

    // 更新总未读数
    _totalUnreadCount += (count - oldCount);

    await _updateBadge();
  }

  /// 增加房间未读数
  ///
  /// [roomId] 房间ID
  /// [increment] 增加数量，默认为1
  Future<void> incrementRoomUnread(String roomId, {int increment = 1}) async {
    final currentCount = _roomUnreadCounts[roomId] ?? 0;
    _roomUnreadCounts[roomId] = currentCount + increment;
    _totalUnreadCount += increment;

    await _updateBadge();
  }

  /// 清除房间未读数（用户已读）
  ///
  /// [roomId] 房间ID
  Future<void> clearRoomUnread(String roomId) async {
    final count = _roomUnreadCounts[roomId] ?? 0;
    if (count > 0) {
      _roomUnreadCounts[roomId] = 0;
      _totalUnreadCount -= count;
      await _updateBadge();
    }
  }

  /// 批量更新房间未读数
  ///
  /// [roomCounts] 房间ID到未读数的映射
  Future<void> updateRoomCounts(Map<String, int> roomCounts) async {
    _roomUnreadCounts.clear();
    _roomUnreadCounts.addAll(roomCounts);

    _totalUnreadCount =
        _roomUnreadCounts.values.fold(0, (sum, count) => sum + count);

    await _updateBadge();
  }

  /// 清除所有未读数
  Future<void> clearAll() async {
    _roomUnreadCounts.clear();
    _totalUnreadCount = 0;

    await _updateBadge();
  }

  /// 获取房间未读数
  int getRoomUnreadCount(String roomId) {
    return _roomUnreadCounts[roomId] ?? 0;
  }

  /// 获取所有房间未读数
  Map<String, int> getAllRoomUnreadCounts() {
    return Map.unmodifiable(_roomUnreadCounts);
  }

  /// 更新桌面图标角标
  Future<void> _updateBadge() async {
    if (!_isInitialized) {
      await initialize();
    }

    if (!_isBadgeSupported) {
      return;
    }

    try {
      if (Platform.isIOS) {
        // iOS: 使用通知设置 badge
        await _updateIOSBadge();
      } else if (Platform.isAndroid) {
        // Android: 通过显示静默通知来更新 badge
        await _updateAndroidBadge();
      }

      debugPrint('AppBadgeService: Badge updated to $_totalUnreadCount');
    } catch (e) {
      debugPrint('AppBadgeService update badge error: $e');
    }
  }

  /// 更新 iOS badge
  Future<void> _updateIOSBadge() async {
    try {
      final iosPlugin = _notifications
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();

      if (iosPlugin != null) {
        await iosPlugin.requestPermissions(badge: true);

        if (_totalUnreadCount <= 0) {
          // 清除 badge
          await _notifications.cancel(_badgeNotificationId);
        } else {
          // iOS 上通过显示通知来设置 badge
          final iosDetails = DarwinNotificationDetails(
            presentAlert: false,
            presentBadge: true,
            presentSound: false,
            badgeNumber: _totalUnreadCount,
          );

          final details = NotificationDetails(iOS: iosDetails);

          await _notifications.show(
            _badgeNotificationId,
            '',
            '',
            details,
          );
        }
      }
    } catch (e) {
      debugPrint('AppBadgeService iOS badge error: $e');
    }
  }

  /// 更新 Android badge
  /// 通过显示静默通知来触发 badge 更新
  Future<void> _updateAndroidBadge() async {
    try {
      if (_totalUnreadCount <= 0) {
        // 清除 badge 通知
        await _notifications.cancel(_badgeNotificationId);
      } else {
        // 显示一个静默通知来更新 badge
        // badge 数量通过通知频道的 showBadge 属性和通知的 number 属性控制
        final androidDetails = AndroidNotificationDetails(
          _badgeChannelId,
          '未读消息角标',
          channelDescription: '用于显示桌面图标上的未读消息数',
          importance: Importance.min,
          priority: Priority.min,
          playSound: false,
          enableVibration: false,
          enableLights: false,
          // 使用极小图标使其几乎不可见
          icon: '@android:drawable/stat_notify_more',
          // 隐藏通知内容
          silent: true,
          // 设置通知数量
          number: _totalUnreadCount,
        );

        final details = NotificationDetails(android: androidDetails);

        await _notifications.show(
          _badgeNotificationId,
          '$_totalUnreadCount 条未读消息',
          '点击查看',
          details,
        );
      }
    } catch (e) {
      debugPrint('AppBadgeService Android badge error: $e');
    }
  }

  /// 刷新角标（从外部数据源重新计算）
  ///
  /// 通常在应用启动或从后台恢复时调用
  Future<void> refreshBadge() async {
    await _updateBadge();
  }

  /// 释放资源
  void dispose() {
    _roomUnreadCounts.clear();
    _totalUnreadCount = 0;
  }
}

/// 全局角标服务实例
final appBadgeService = AppBadgeService();
