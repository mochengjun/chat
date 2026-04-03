import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'app/app.dart';
import 'core/di/injection.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/notification_sound_service.dart';
import 'core/services/local_notification_service.dart';
import 'core/services/background_service.dart';
import 'core/services/app_badge_service.dart';
import 'core/services/global_navigation_service.dart';

void main() async {
  // 捕获所有同步错误
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    
    debugPrint('[Main] App starting...');
    
    // 设置全局错误捕获
    FlutterError.onError = (details) {
      debugPrint('[FlutterError] ${details.exception}');
      debugPrint('[FlutterError] ${details.stack}');
    };
    
    // 检测是否为移动平台
    final isMobilePlatform = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    debugPrint('[Main] isMobilePlatform: $isMobilePlatform');
    
    // 仅在移动平台上初始化 Firebase
    bool firebaseInitialized = false;
    if (isMobilePlatform) {
      try {
        debugPrint('[Main] Initializing Firebase...');
        await Firebase.initializeApp();
        FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
        firebaseInitialized = true;
        debugPrint('[Main] Firebase initialized');
      } catch (e, stack) {
        debugPrint('[Main] Firebase initialization failed: $e');
        debugPrint('[Main] Stack: $stack');
        // Firebase 初始化失败不影响应用运行，继续启动
      }
    }
    
    // 初始化依赖注入
    try {
      debugPrint('[Main] Configuring dependencies...');
      await configureDependencies();
      debugPrint('[Main] Dependencies configured');
    } catch (e, stack) {
      debugPrint('[Main] DI configuration failed: $e');
      debugPrint('[Main] Stack: $stack');
    }
    
    // 设置 Bloc 观察者
    Bloc.observer = AppBlocObserver();
    
    debugPrint('[Main] Running app...');
    // 启动应用
    runApp(const RestartWidget(child: SecChatApp()));
    
    // 延迟初始化非核心服务
    _initializeServicesAsync(isMobilePlatform, firebaseInitialized);
    
  }, (error, stack) {
    debugPrint('[ZoneError] $error');
    debugPrint('[ZoneError] $stack');
  });
}

/// 异步初始化非核心服务
void _initializeServicesAsync(bool isMobilePlatform, bool firebaseInitialized) {
  // 延迟确保应用完全启动后再初始化服务
  Future.delayed(const Duration(seconds: 2), () async {
    // 初始化通知相关服务
    try {
      await localNotificationService.initialize();
      await notificationSoundService.initialize();
      // 初始化桌面图标角标服务
      await appBadgeService.initialize();
      debugPrint('[Main] Notification services initialized');
    } catch (e) {
      debugPrint('Notification service initialization failed: $e');
    }

    // 仅在移动平台上初始化推送和后台服务
    if (isMobilePlatform && firebaseInitialized) {
      // 推送服务（顺序初始化，不再额外延迟）
      try {
        if (getIt.isRegistered<PushNotificationService>()) {
          final pushService = getIt<PushNotificationService>();
          
          // 设置FCM通知点击回调
          pushService.onNotificationTap = (data) {
            debugPrint('FCM notification tapped: ${data.roomId}');
            if (data.roomId != null) {
              GlobalNavigationService.navigateToRoom(data.roomId!);
            }
          };
          
          await pushService.initialize();
          debugPrint('[Main] Push service initialized');
        }
      } catch (e) {
        debugPrint('Push notification initialization failed: $e');
      }

      // 后台服务（顺序初始化，不再额外延迟）
      try {
        await backgroundServiceManager.initialize();
        await backgroundServiceManager.startService();
        debugPrint('[Main] Background service started');
      } catch (e) {
        debugPrint('Background service initialization failed: $e');
      }
    }

    // 处理挂起的通知导航（所有服务初始化完成后）
    GlobalNavigationService.processPendingNavigation();
  });
}

/// 应用重启 Widget
/// 通过替换 Key 强制重建整个 Widget 树
class RestartWidget extends StatefulWidget {
  final Widget child;

  const RestartWidget({super.key, required this.child});

  /// 重启应用：重置 DI 容器并重新初始化
  static Future<void> restart(BuildContext context) async {
    final state = context.findAncestorStateOfType<_RestartWidgetState>();
    await getIt.reset();
    await configureDependencies();
    state?._restart();
  }

  @override
  State<RestartWidget> createState() => _RestartWidgetState();
}

class _RestartWidgetState extends State<RestartWidget> {
  Key _key = UniqueKey();

  void _restart() {
    setState(() {
      _key = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: _key,
      child: widget.child,
    );
  }
}

/// Bloc 观察者用于调试
class AppBlocObserver extends BlocObserver {
  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);
    debugPrint('${bloc.runtimeType} $change');
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    debugPrint('${bloc.runtimeType} $error $stackTrace');
    super.onError(bloc, error, stackTrace);
  }
}
