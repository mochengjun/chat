import 'package:intl/intl.dart';

/// 时间工具函数集合
/// 用于处理时间的本地化显示，与Web客户端保持一致
class TimeUtils {
  TimeUtils._();

  /// 格式化时间为本地时间显示（HH:mm格式）
  static String formatLocalTime(DateTime date) {
    return DateFormat('HH:mm').format(date);
  }

  /// 格式化详细时间（用于tooltip显示）
  static String formatDetailedTime(DateTime date) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(date);
  }

  /// 判断是否为今天
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// 判断是否为昨天
  static bool isYesterday(DateTime date) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day;
  }

  /// 获取相对日期描述
  /// 返回格式：今天/昨天/M月D日/yyyy年M月D日
  static String getRelativeDateDescription(DateTime date) {
    final now = DateTime.now();

    if (isToday(date)) {
      return '今天';
    } else if (isYesterday(date)) {
      return '昨天';
    } else if (date.year == now.year) {
      return DateFormat('M月d日').format(date);
    } else {
      return DateFormat('yyyy年M月d日').format(date);
    }
  }
}
