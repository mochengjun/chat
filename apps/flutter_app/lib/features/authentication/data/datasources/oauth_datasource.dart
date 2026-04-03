import 'dart:async';
import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/network/dio_client.dart';
import '../../domain/entities/user.dart';

/// OAuth 提供商类型
enum OAuthProvider {
  google,
  wechat,
}

/// OAuth 登录结果
class OAuthResult {
  final String? accessToken;
  final String? refreshToken;
  final int? expiresIn;
  final User? user;
  final String? errorMessage;

  const OAuthResult({
    this.accessToken,
    this.refreshToken,
    this.expiresIn,
    this.user,
    this.errorMessage,
  });

  bool get isSuccess => accessToken != null && errorMessage == null;
}

/// OAuth 数据源抽象类
abstract class OAuthDataSource {
  /// 获取 Google 登录凭据
  Future<String?> getGoogleIdToken();

  /// 使用 OAuth 凭据登录后端
  Future<OAuthResult> loginWithOAuth({
    required OAuthProvider provider,
    required String credential,
  });

  /// 登出
  Future<void> signOut();
}

class OAuthDataSourceImpl implements OAuthDataSource {
  final DioClient _client;
  final GoogleSignIn _googleSignIn;

  OAuthDataSourceImpl(this._client)
      : _googleSignIn = GoogleSignIn(
          scopes: [
            'email',
            'profile',
          ],
        );

  @override
  Future<String?> getGoogleIdToken() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) {
        return null; // 用户取消登录
      }

      final GoogleSignInAuthentication auth = await account.authentication;
      return auth.idToken;
    } catch (e) {
      debugPrint('Google Sign-In error (details redacted)');
      return null;
    }
  }

  @override
  Future<OAuthResult> loginWithOAuth({
    required OAuthProvider provider,
    required String credential,
  }) async {
    try {
      final providerName = provider == OAuthProvider.google ? 'google' : 'wechat';

      final response = await _client.post(
        '/auth/oauth/$providerName',
        data: {
          'credential': credential,
          'provider': providerName,
        },
      );

      final data = response.data;

      if (data['error'] != null) {
        return OAuthResult(errorMessage: data['error']);
      }

      _client.setAuthToken(data['access_token']);

      return OAuthResult(
        accessToken: data['access_token'],
        refreshToken: data['refresh_token'],
        expiresIn: data['expires_in'],
      );
    } on DioException catch (e) {
      return OAuthResult(
        errorMessage: _mapDioError(e),
      );
    } catch (e) {
      return OAuthResult(
        errorMessage: 'OAuth 登录失败: ${e.toString()}',
      );
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('Google Sign-Out error (details redacted)');
    }
  }

  String _mapDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '连接服务器超时，请检查网络连接';
      case DioExceptionType.connectionError:
        return '无法连接到服务器，请检查网络';
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        if (statusCode == 401) {
          return 'OAuth 授权无效或已过期';
        } else if (statusCode == 404) {
          return 'OAuth 登录暂不支持';
        } else if (statusCode != null && statusCode >= 500) {
          return '服务器内部错误，请稍后重试';
        }
        return '请求失败 ($statusCode)';
      default:
        return '网络连接失败，请检查网络';
    }
  }
}
