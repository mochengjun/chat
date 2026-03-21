import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:dio/dio.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/login_usecase.dart';
import '../../domain/usecases/register_usecase.dart';
import '../../domain/usecases/logout_usecase.dart';
import '../../domain/usecases/oauth_login_usecase.dart';
import '../../../../core/services/notification_sound_service.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginUseCase loginUseCase;
  final RegisterUseCase registerUseCase;
  final LogoutUseCase logoutUseCase;
  final OAuthLoginUseCase oauthLoginUseCase;

  AuthBloc({
    required this.loginUseCase,
    required this.registerUseCase,
    required this.logoutUseCase,
    required this.oauthLoginUseCase,
  }) : super(AuthInitial()) {
    on<LoginRequested>(_onLoginRequested);
    on<RegisterRequested>(_onRegisterRequested);
    on<LogoutRequested>(_onLogoutRequested);
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<GoogleLoginRequested>(_onGoogleLoginRequested);
    on<WeChatLoginRequested>(_onWeChatLoginRequested);
  }

  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    
    try {
      final result = await loginUseCase(
        username: event.username,
        password: event.password,
        deviceId: event.deviceId,
        deviceName: event.deviceName,
        deviceType: event.deviceType,
      );

      if (result.mfaRequired) {
        emit(AuthMFARequired(
          username: event.username,
          password: event.password,
        ));
      } else {
        emit(AuthAuthenticated(user: result.user));
      }
    } catch (e) {
      // 判断是否是连接错误，如果是则播放错误提示音
      if (_isConnectionError(e)) {
        notificationSoundService.playErrorSound();
      }
      emit(AuthError(message: _mapErrorMessage(e)));
    }
  }

  Future<void> _onRegisterRequested(
    RegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    
    try {
      final user = await registerUseCase(
        username: event.username,
        password: event.password,
        phoneNumber: event.phoneNumber,
        email: event.email,
        displayName: event.displayName,
      );
      emit(AuthRegistered(user: user));
    } catch (e) {
      // 判断是否是连接错误，如果是则播放错误提示音
      if (_isConnectionError(e)) {
        notificationSoundService.playErrorSound();
      }
      emit(AuthError(message: _mapErrorMessage(e)));
    }
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    
    try {
      await logoutUseCase();
      emit(AuthUnauthenticated());
    } catch (e) {
      emit(AuthError(message: e.toString()));
    }
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    // TODO: 检查本地存储的 token 是否有效
    emit(AuthUnauthenticated());
  }

  /// 将异常转换为用户友好的中文错误消息
  String _mapErrorMessage(Object e) {
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return '连接服务器超时，请检查网络连接';
        case DioExceptionType.connectionError:
          final msg = e.message ?? '';
          if (msg.contains('No route to host') ||
              msg.contains('Connection refused') ||
              msg.contains('Network is unreachable')) {
            return '无法连接到服务器，请检查网络或重开ZeroTier';
          }
          return '网络连接失败，请检查网络或重开ZeroTier';
        case DioExceptionType.badResponse:
          final statusCode = e.response?.statusCode;
          if (statusCode == 401) {
            return '用户名或密码错误';
          } else if (statusCode == 403) {
            return '账号已被禁用，请联系管理员';
          } else if (statusCode != null && statusCode >= 500) {
            return '服务器内部错误，请稍后重试';
          }
          return '请求失败 ($statusCode)';
        case DioExceptionType.cancel:
          return '请求已取消';
        default:
          return '网络连接失败，请检查网络或重开ZeroTier';
      }
    }
    return '操作失败: ${e.toString()}';
  }

  /// 判断是否是连接错误
  bool _isConnectionError(Object e) {
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
          return true;
        case DioExceptionType.badResponse:
          final statusCode = e.response?.statusCode;
          // 401/403 也算连接/认证错误
          return statusCode == 401 || statusCode == 403 || (statusCode != null && statusCode >= 500);
        default:
          return false;
      }
    }
    return false;
  }

  /// Google 登录处理
  Future<void> _onGoogleLoginRequested(
    GoogleLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      final result = await oauthLoginUseCase.loginWithGoogle();

      if (result.isCancelled) {
        emit(AuthUnauthenticated());
        return;
      }

      if (result.isSuccess && result.user != null) {
        emit(AuthAuthenticated(user: result.user!));
      } else {
        emit(AuthError(message: result.errorMessage ?? 'Google 登录失败'));
      }
    } catch (e) {
      notificationSoundService.playErrorSound();
      emit(AuthError(message: 'Google 登录失败: ${e.toString()}'));
    }
  }

  /// 微信登录处理
  Future<void> _onWeChatLoginRequested(
    WeChatLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    try {
      // 微信登录暂未实现
      emit(AuthError(message: '微信登录暂未实现，敬请期待'));
    } catch (e) {
      notificationSoundService.playErrorSound();
      emit(AuthError(message: '微信登录失败: ${e.toString()}'));
    }
  }
}
