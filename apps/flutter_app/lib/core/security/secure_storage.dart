import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  // 禁用 encryptedSharedPreferences，使用标准存储避免某些 Android 设备崩溃
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: false,
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_PKCS1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_CBC_PKCS7Padding,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // In-memory cache for synchronous access
  String? _cachedAccessToken;

  // 存储 Key 常量
  static const String keyAccessToken = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyUserId = 'user_id';
  static const String keyUsername = 'username';
  static const String keyDeviceId = 'device_id';

  /// 初始化服务，预加载 token 到内存缓存
  /// 必须在应用启动时调用，确保同步方法能正确返回 token
  Future<void> initialize() async {
    try {
      _cachedAccessToken = await _storage.read(key: keyAccessToken);
    } catch (e) {
      // 初始化失败时，缓存保持为空
      _cachedAccessToken = null;
    }
  }

  // 写入数据
  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  // 读取数据
  Future<String?> read(String key) async {
    return await _storage.read(key: key);
  }

  // 删除数据
  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }

  // 删除所有数据
  Future<void> deleteAll() async {
    await _storage.deleteAll();
  }

  // 检查 Key 是否存在
  Future<bool> containsKey(String key) async {
    return await _storage.containsKey(key: key);
  }

  // Token 相关便捷方法
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _cachedAccessToken = accessToken;
    await write(keyAccessToken, accessToken);
    await write(keyRefreshToken, refreshToken);
  }

  Future<String?> getAccessToken() async {
    _cachedAccessToken = await read(keyAccessToken);
    return _cachedAccessToken;
  }

  // Synchronous access to cached token (for WebSocket)
  String? getAccessTokenSync() => _cachedAccessToken;

  Future<String?> getRefreshToken() async {
    return await read(keyRefreshToken);
  }

  Future<void> clearTokens() async {
    _cachedAccessToken = null;
    await delete(keyAccessToken);
    await delete(keyRefreshToken);
  }

  // 用户信息相关
  Future<void> saveUserInfo({
    required String userId,
    required String username,
  }) async {
    await write(keyUserId, userId);
    await write(keyUsername, username);
  }

  Future<Map<String, String?>> getUserInfo() async {
    return {
      'userId': await read(keyUserId),
      'username': await read(keyUsername),
    };
  }

  Future<void> clearUserInfo() async {
    await delete(keyUserId);
    await delete(keyUsername);
  }

  // 清除所有认证数据
  Future<void> clearAuth() async {
    await clearTokens();
    await clearUserInfo();
  }
}
