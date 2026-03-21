import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../datasources/auth_local_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<AuthResult> login({
    required String username,
    required String password,
    String? deviceId,
    String? deviceName,
    String? deviceType,
  }) async {
    final result = await remoteDataSource.login(
      username: username,
      password: password,
      deviceId: deviceId,
      deviceName: deviceName,
      deviceType: deviceType,
    );

    if (!result.mfaRequired && result.accessToken != null) {
      await localDataSource.saveTokens(
        accessToken: result.accessToken!,
        refreshToken: result.refreshToken!,
      );
      
      // 登录成功后获取用户信息并保存
      try {
        final user = await remoteDataSource.getCurrentUser();
        await localDataSource.saveUserInfo(
          userId: user.userId,
          username: user.username,
        );
      } catch (e) {
        // 获取用户信息失败不影响登录流程
        print('Failed to get current user info: $e');
      }
    }

    return result;
  }

  @override
  Future<User> register({
    required String username,
    required String password,
    String? phoneNumber,
    String? email,
    String? displayName,
  }) async {
    return remoteDataSource.register(
      username: username,
      password: password,
      phoneNumber: phoneNumber,
      email: email,
      displayName: displayName,
    );
  }

  @override
  Future<AuthResult> refreshToken(String refreshToken) async {
    final result = await remoteDataSource.refreshToken(refreshToken);

    if (result.accessToken != null) {
      await localDataSource.saveTokens(
        accessToken: result.accessToken!,
        refreshToken: result.refreshToken!,
      );
    }

    return result;
  }

  @override
  Future<void> logout() async {
    final refreshToken = await localDataSource.getRefreshToken();
    
    try {
      await remoteDataSource.logout(refreshToken: refreshToken);
    } finally {
      await localDataSource.clearAuth();
    }
  }

  @override
  Future<User?> getCurrentUser() async {
    final accessToken = await localDataSource.getAccessToken();
    if (accessToken == null) return null;

    try {
      return await remoteDataSource.getCurrentUser();
    } catch (e) {
      return null;
    }
  }

  @override
  Future<bool> isLoggedIn() async {
    final accessToken = await localDataSource.getAccessToken();
    return accessToken != null;
  }

  @override
  Future<AuthResult> verifyMFA({
    required String username,
    required String password,
    required String code,
    String? deviceId,
  }) async {
    final result = await remoteDataSource.verifyMFA(
      username: username,
      password: password,
      code: code,
      deviceId: deviceId,
    );

    if (result.accessToken != null) {
      await localDataSource.saveTokens(
        accessToken: result.accessToken!,
        refreshToken: result.refreshToken!,
      );
      
      // MFA 验证成功后也获取用户信息并保存
      try {
        final user = await remoteDataSource.getCurrentUser();
        await localDataSource.saveUserInfo(
          userId: user.userId,
          username: user.username,
        );
      } catch (e) {
        print('Failed to get current user info after MFA: $e');
      }
    }

    return result;
  }
}
