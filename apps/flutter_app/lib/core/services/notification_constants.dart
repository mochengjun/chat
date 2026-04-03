/// 通知相关常量配置
///
/// 统一管理通知频道ID、配置参数等，确保各服务使用一致的配置
class NotificationConstants {
  NotificationConstants._();

  // ==================== 通知频道 ====================

  /// 聊天消息通知频道ID
  static const String chatMessagesChannelId = 'chat_messages_v2';

  /// 聊天消息通知频道名称
  static const String chatMessagesChannelName = '聊天消息';

  /// 聊天消息通知频道描述
  static const String chatMessagesChannelDescription = '新消息通知（含声音）';

  /// 后台服务通知频道ID
  static const String backgroundServiceChannelId = 'sec_chat_background';

  /// 后台服务通知频道名称
  static const String backgroundServiceChannelName = 'SecChat后台服务';

  /// 后台服务通知频道描述
  static const String backgroundServiceChannelDescription = '保持消息连接活跃';

  /// Badge角标通知频道ID
  static const String badgeChannelId = 'badge_channel';

  // ==================== 通知ID范围 ====================

  /// 消息通知ID最小值
  static const int messageNotificationIdMin = 1000000;

  /// 消息通知ID最大值
  static const int messageNotificationIdMax = 9999999;

  /// 后台服务通知ID
  static const int backgroundServiceNotificationId = 888;

  /// Badge通知ID
  static const int badgeNotificationId = 999999;

  // ==================== 通知ID子范围 ====================

  /// 前台本地通知ID范围
  static const int localNotificationIdMin = 1000000;
  static const int localNotificationIdMax = 3999999;

  /// FCM后台通知ID范围
  static const int fcmNotificationIdMin = 4000000;
  static const int fcmNotificationIdMax = 6999999;

  /// 后台服务通知ID范围
  static const int backgroundNotificationIdMin = 7000000;
  static const int backgroundNotificationIdMax = 9999999;

  // ==================== 节流配置 ====================

  /// 消息通知节流间隔（毫秒）
  static const int notificationThrottleMs = 1500;

  /// 消息提示音节流间隔（毫秒）
  static const int soundThrottleMs = 800;

  /// 错误提示音节流间隔（毫秒）
  static const int errorSoundThrottleMs = 3000;

  // ==================== 通知分组 ====================

  /// 聊天消息通知分组Key
  static const String chatMessagesGroupKey = 'chat_messages_group';

  // ==================== Payload格式 ====================

  /// Payload分隔符
  static const String payloadSeparator = '|';

  /// Payload类型：本地通知
  static const String payloadTypeLocal = 'local';

  /// Payload类型：FCM通知
  static const String payloadTypeFcm = 'fcm';

  // ==================== 通知配置 ====================

  /// 最大合并消息数
  static const int maxMergedMessages = 10;

  /// 通知内容最大长度
  static const int maxNotificationContentLength = 500;

  /// 通知自动取消
  static const bool autoCancel = true;

  /// 显示时间戳
  static const bool showWhen = true;

  // ==================== 通知ID生成 ====================

  /// 基于消息ID生成确定性通知ID
  /// 同一 messageId 无论从 WebSocket、FCM 还是后台隔离触发，
  /// 都会生成相同的通知 ID，Android 系统会自动替换而非重复创建
  static int messageIdToNotificationId(String messageId) {
    // FNV-1a hash
    var hash = 0x811c9dc5;
    for (var i = 0; i < messageId.length; i++) {
      hash ^= messageId.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return (hash.abs() % (messageNotificationIdMax - messageNotificationIdMin)) + messageNotificationIdMin;
  }
}

/// 通知消息缓存，用于通知合并和去重
class NotificationCache {
  static final NotificationCache _instance = NotificationCache._internal();
  factory NotificationCache() => _instance;
  NotificationCache._internal();

  /// 最近通知的消息ID集合（用于去重）
  final Set<String> _recentMessageIds = {};

  /// 房间消息列表（用于通知合并）
  final Map<String, List<NotificationMessage>> _roomMessages = {};

  /// 房间节流时间记录
  final Map<String, DateTime> _roomThrottleTimes = {};

  /// 检查并添加消息ID（返回是否为重复消息）
  bool checkAndAddMessageId(String messageId) {
    if (_recentMessageIds.contains(messageId)) {
      return true; // 重复消息
    }
    _recentMessageIds.add(messageId);

    // 保持缓存大小限制
    if (_recentMessageIds.length > 100) {
      _recentMessageIds.remove(_recentMessageIds.first);
    }
    return false;
  }

  /// 添加房间消息
  void addRoomMessage(String roomId, NotificationMessage message) {
    _roomMessages.putIfAbsent(roomId, () => []);
    _roomMessages[roomId]!.add(message);

    // 保持每个房间的消息数量限制
    if (_roomMessages[roomId]!.length > NotificationConstants.maxMergedMessages) {
      _roomMessages[roomId]!.removeAt(0);
    }
  }

  /// 获取房间消息列表
  List<NotificationMessage> getRoomMessages(String roomId) {
    return _roomMessages[roomId] ?? [];
  }

  /// 清除房间消息
  void clearRoomMessages(String roomId) {
    _roomMessages.remove(roomId);
  }

  /// 检查指定房间是否应该节流
  bool shouldThrottle(String roomId) {
    final lastTime = _roomThrottleTimes[roomId];
    if (lastTime == null) {
      _roomThrottleTimes[roomId] = DateTime.now();
      return false;
    }

    final elapsed = DateTime.now().difference(lastTime);
    if (elapsed.inMilliseconds < NotificationConstants.notificationThrottleMs) {
      return true;
    }

    _roomThrottleTimes[roomId] = DateTime.now();
    return false;
  }

  /// 清除所有缓存
  void clearAll() {
    _recentMessageIds.clear();
    _roomMessages.clear();
    _roomThrottleTimes.clear();
  }
}

/// 通知消息模型
class NotificationMessage {
  final String messageId;
  final String senderName;
  final String content;
  final DateTime timestamp;

  NotificationMessage({
    required this.messageId,
    required this.senderName,
    required this.content,
    required this.timestamp,
  });
}

/// 全局通知缓存实例
final notificationCache = NotificationCache();
