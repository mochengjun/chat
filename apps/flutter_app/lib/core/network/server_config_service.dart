import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'network_config.dart';

/// 服务器地址配置服务
/// 负责持久化读写服务器地址配置
class ServerConfigService {
  static const String _keyServerHost = 'server_host';
  static const String _keyServerPort = 'server_port';

  // 直接使用 FlutterSecureStorage，不依赖 DI（启动阶段需要在 DI 初始化前使用）
  // 禁用 encryptedSharedPreferences，与 SecureStorageService 保持一致，
  // 避免某些 Android 设备上的存储崩溃问题
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: false,
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_PKCS1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_CBC_PKCS7Padding,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// 验证端口是否在有效范围内 (1-65535)
  static bool _isValidPort(int? port) {
    return port != null && port >= 1 && port <= 65535;
  }

  /// 加载服务器配置（静态方法，可在 DI 初始化前调用）
  /// 若无存储值，返回 NetworkConfig 中的平台特定默认值
  static Future<({String host, int port})> loadConfig() async {
    // 使用平台特定的默认主机地址（Android模拟器使用10.0.2.2）
    final defaultHost = NetworkConfig.getDefaultHostForPlatform();

    try {
      final host = await _storage.read(key: _keyServerHost);
      final portStr = await _storage.read(key: _keyServerPort);
      final port = portStr != null ? int.tryParse(portStr) : null;

      // 验证端口范围
      if (!_isValidPort(port)) {
        debugPrint('ServerConfigService: Invalid port value $port, using default');
      }

      return (
        host: host ?? defaultHost,
        port: _isValidPort(port) ? port! : NetworkConfig.defaultServerPort,
      );
    } catch (e) {
      debugPrint('[ServerConfigService] loadConfig error: $e, using defaults');
      return (
        host: defaultHost,
        port: NetworkConfig.defaultServerPort,
      );
    }
  }

  /// 保存服务器配置
  Future<void> saveConfig(String host, int port) async {
    // 验证端口范围
    if (!_isValidPort(port)) {
      throw ArgumentError('Port must be between 1 and 65535, got: $port');
    }
    try {
      await _storage.write(key: _keyServerHost, value: host);
      await _storage.write(key: _keyServerPort, value: port.toString());
    } catch (e) {
      debugPrint('[ServerConfigService] saveConfig error: $e');
      rethrow;
    }
  }

  /// 构建 API 基础 URL
  static String buildApiBaseUrl(String host, int port) {
    return 'http://$host:$port/api/v1';
  }
}
