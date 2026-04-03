import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../../core/network/dio_client.dart';

abstract class AuthRemoteDataSource {
  Future<AuthResult> login({
    required String username,
    required String password,
    String? deviceId,
    String? deviceName,
    String? deviceType,
  });

  Future<User> register({
    required String username,
    required String password,
    String? phoneNumber,
    String? email,
    String? displayName,
  });

  Future<AuthResult> refreshToken(String refreshToken);

  Future<void> logout({String? refreshToken});

  Future<User> getCurrentUser();

  Future<AuthResult> verifyMFA({
    required String username,
    required String password,
    required String code,
    String? deviceId,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final DioClient _client;

  AuthRemoteDataSourceImpl(this._client);

  @override
  Future<AuthResult> login({
    required String username,
    required String password,
    String? deviceId,
    String? deviceName,
    String? deviceType,
  }) async {
    try {
      final response = await _client.post(
        '/auth/login',
        data: {
          'username': username,
          'password': password,
          if (deviceId != null) 'device_id': deviceId,
          if (deviceName != null) 'device_name': deviceName,
          if (deviceType != null) 'device_type': deviceType,
        },
      );

      final data = response.data;
      if (data == null) {
        throw Exception('登录响应数据为空');
      }

      if (data['mfa_required'] == true) {
        return const AuthResult(mfaRequired: true);
      }

      final accessToken = data['access_token'] as String?;
      if (accessToken == null) {
        throw Exception('登录响应缺少访问令牌');
      }

      _client.setAuthToken(accessToken);

      return AuthResult(
        accessToken: accessToken,
        refreshToken: data['refresh_token'] as String?,
        expiresIn: data['expires_in'] as int?,
      );
    } on DioException catch (e) {
      debugPrint('Login failed: ${e.type}');
      rethrow;
    }
  }

  @override
  Future<User> register({
    required String username,
    required String password,
    String? phoneNumber,
    String? email,
    String? displayName,
  }) async {
    try {
      final response = await _client.post(
        '/auth/register',
        data: {
          'username': username,
          'password': password,
          if (phoneNumber != null) 'phone_number': phoneNumber,
          if (email != null) 'email': email,
          if (displayName != null) 'display_name': displayName,
        },
      );

      final data = response.data;
      if (data == null) {
        throw Exception('注册响应数据为空');
      }

      final userId = data['user_id'] as String?;
      if (userId == null) {
        throw Exception('注册响应缺少用户ID');
      }

      return User(
        userId: userId,
        username: data['username'] as String? ?? username,
        createdAt: DateTime.now(),
      );
    } on DioException catch (e) {
      debugPrint('Register failed: ${e.type}');
      rethrow;
    }
  }

  @override
  Future<AuthResult> refreshToken(String refreshToken) async {
    try {
      final response = await _client.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );

      final data = response.data;
      if (data == null) {
        throw Exception('刷新令牌响应数据为空');
      }

      final accessToken = data['access_token'] as String?;
      if (accessToken == null) {
        throw Exception('刷新令牌响应缺少访问令牌');
      }

      _client.setAuthToken(accessToken);

      return AuthResult(
        accessToken: accessToken,
        refreshToken: data['refresh_token'] as String?,
        expiresIn: data['expires_in'] as int?,
      );
    } on DioException catch (e) {
      debugPrint('Refresh token failed: ${e.type}');
      rethrow;
    }
  }

  @override
  Future<void> logout({String? refreshToken}) async {
    await _client.post(
      '/auth/logout',
      data: {
        if (refreshToken != null) 'refresh_token': refreshToken,
      },
    );
    _client.clearAuthToken();
  }

  @override
  Future<User> getCurrentUser() async {
    final response = await _client.get('/auth/me');
    final data = response.data;

    return User(
      userId: data['user_id'],
      username: data['username'],
      phoneNumber: data['phone_number'],
      email: data['email'],
      displayName: data['display_name'],
      avatarUrl: data['avatar_url'],
      mfaEnabled: data['mfa_enabled'] ?? false,
      isActive: data['is_active'] ?? true,
      createdAt: DateTime.parse(data['created_at']),
    );
  }

  @override
  Future<AuthResult> verifyMFA({
    required String username,
    required String password,
    required String code,
    String? deviceId,
  }) async {
    try {
      final response = await _client.post(
        '/auth/verify-mfa',
        data: {
          'username': username,
          'password': password,
          'code': code,
          if (deviceId != null) 'device_id': deviceId,
        },
      );

      final data = response.data;
      if (data == null) {
        throw Exception('MFA验证响应数据为空');
      }

      final accessToken = data['access_token'] as String?;
      if (accessToken == null) {
        throw Exception('MFA验证响应缺少访问令牌');
      }

      _client.setAuthToken(accessToken);

      return AuthResult(
        accessToken: accessToken,
        refreshToken: data['refresh_token'] as String?,
        expiresIn: data['expires_in'] as int?,
      );
    } on DioException catch (e) {
      debugPrint('MFA verify failed: ${e.type}');
      rethrow;
    }
  }
}
