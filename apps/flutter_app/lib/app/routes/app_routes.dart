import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../features/authentication/presentation/pages/login_page.dart';
import '../../features/authentication/presentation/pages/register_page.dart';
import '../../features/authentication/presentation/bloc/auth_bloc.dart';
import '../../features/chat/presentation/pages/room_list_page.dart';
import '../../features/chat/presentation/pages/chat_room_page.dart';
import '../../core/services/global_navigation_service.dart';

final appRouter = GoRouter(
  navigatorKey: GlobalNavigationService.navigatorKey,
  initialLocation: '/login',
  routes: [
    // 认证路由
    GoRoute(
      path: '/login',
      name: 'login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/register',
      name: 'register',
      builder: (context, state) => const RegisterPage(),
    ),
    
    // 主页路由
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const RoomListPage(),
      routes: [
        GoRoute(
          path: 'room/:roomId',
          name: 'chatRoom',
          builder: (context, state) {
            final roomId = state.pathParameters['roomId']!;
            return ChatRoomPage(roomId: roomId);
          },
        ),
      ],
    ),
  ],
  
  // 错误页面
  errorBuilder: (context, state) => Scaffold(
    body: Center(
      child: Text('Page not found: ${state.uri}'),
    ),
  ),
  
  // 路由重定向（用于认证检查）
  redirect: (context, state) {
    // 获取 AuthBloc 状态
    final authState = context.read<AuthBloc>().state;
    final isAuthenticated = authState is AuthAuthenticated;
    final isAuthRoute = state.matchedLocation == '/login' || 
                         state.matchedLocation == '/register';

    // 未认证用户访问受保护路由，重定向到登录页
    if (!isAuthenticated && !isAuthRoute) {
      return '/login';
    }

    // 已认证用户访问登录/注册页，重定向到首页
    if (isAuthenticated && isAuthRoute) {
      return '/';
    }

    return null;
  },
);
