import '../entities/user.dart';
import '../repositories/auth_repository.dart';
import '../../data/datasources/oauth_datasource.dart';

/// OAuth 登录用例
class OAuthLoginUseCase {
  final OAuthDataSource _oauthDataSource;
  final AuthRepository _authRepository;

  OAuthLoginUseCase({
    required OAuthDataSource oauthDataSource,
    required AuthRepository authRepository,
  })  : _oauthDataSource = oauthDataSource,
        _authRepository = authRepository;

  /// Google 登录
  Future<OAuthLoginResult> loginWithGoogle() async {
    try {
      // 1. 获取 Google ID Token
      final idToken = await _oauthDataSource.getGoogleIdToken();
      if (idToken == null) {
        return OAuthLoginResult.cancelled();
      }

      // 2. 使用 ID Token 登录后端
      final result = await _oauthDataSource.loginWithOAuth(
        provider: OAuthProvider.google,
        credential: idToken,
      );

      if (!result.isSuccess) {
        return OAuthLoginResult.error(result.errorMessage ?? '登录失败');
      }

      // 3. 获取用户信息
      final user = await _authRepository.getCurrentUser();

      return OAuthLoginResult.success(
        accessToken: result.accessToken!,
        refreshToken: result.refreshToken!,
        expiresIn: result.expiresIn,
        user: user,
      );
    } catch (e) {
      return OAuthLoginResult.error('Google 登录失败: ${e.toString()}');
    }
  }

  /// 登出
  Future<void> signOut() async {
    await _oauthDataSource.signOut();
  }
}

/// OAuth 登录结果
class OAuthLoginResult {
  final bool isSuccess;
  final bool isCancelled;
  final String? errorMessage;
  final String? accessToken;
  final String? refreshToken;
  final int? expiresIn;
  final User? user;

  const OAuthLoginResult._({
    required this.isSuccess,
    required this.isCancelled,
    this.errorMessage,
    this.accessToken,
    this.refreshToken,
    this.expiresIn,
    this.user,
  });

  factory OAuthLoginResult.success({
    required String accessToken,
    required String refreshToken,
    int? expiresIn,
    User? user,
  }) {
    return OAuthLoginResult._(
      isSuccess: true,
      isCancelled: false,
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresIn: expiresIn,
      user: user,
    );
  }

  factory OAuthLoginResult.error(String message) {
    return OAuthLoginResult._(
      isSuccess: false,
      isCancelled: false,
      errorMessage: message,
    );
  }

  factory OAuthLoginResult.cancelled() {
    return const OAuthLoginResult._(
      isSuccess: false,
      isCancelled: true,
      errorMessage: '用户取消登录',
    );
  }
}
