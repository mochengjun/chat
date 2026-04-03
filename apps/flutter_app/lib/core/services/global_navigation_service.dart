import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// 全局导航服务
///
/// 用于在非Widget上下文（如通知点击回调、后台服务等）中执行导航操作
class GlobalNavigationService {
  GlobalNavigationService._();

  /// 全局导航Key
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// 获取当前BuildContext
  static BuildContext? get context => navigatorKey.currentContext;

  /// 待处理的房间导航（冷启动时 context 可能为 null）
  static String? _pendingRoomId;

  /// 导航到聊天室
  static void navigateToRoom(String roomId) {
    final ctx = context;
    if (ctx != null) {
      ctx.push('/room/$roomId');
    } else {
      _pendingRoomId = roomId;
      debugPrint('Navigation deferred: room $roomId queued');
    }
  }

  /// 导航到房间列表
  static void navigateToRoomList() {
    final ctx = context;
    if (ctx != null) {
      ctx.go('/');
    }
  }

  /// 导航到设置页面
  static void navigateToSettings() {
    final ctx = context;
    if (ctx != null) {
      ctx.push('/settings');
    }
  }

  /// 导航到登录页面
  static void navigateToLogin() {
    final ctx = context;
    if (ctx != null) {
      ctx.go('/login');
    }
  }

  /// 显示SnackBars
  static void showSnackBar(String message, {bool isError = false}) {
    final ctx = context;
    if (ctx != null) {
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : null,
        ),
      );
    }
  }

  /// 显示对话框
  static Future<T?> showDialog<T>({
    required Widget Function(BuildContext) builder,
    bool barrierDismissible = true,
  }) async {
    final ctx = context;
    if (ctx != null) {
      return showAdaptiveDialog<T>(
        context: ctx,
        builder: builder,
        barrierDismissible: barrierDismissible,
      );
    }
    return null;
  }

  /// 处理挂起的导航请求
  /// 
  /// 在应用初始化完成、context 就绪后调用
  static void processPendingNavigation() {
    if (_pendingRoomId != null && context != null) {
      final roomId = _pendingRoomId!;
      _pendingRoomId = null;
      navigateToRoom(roomId);
    }
  }
}
