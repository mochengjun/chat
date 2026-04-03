import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'network_config.dart';

/// 服务器地址配置服务
/// 负责持久化读写服务器地址配置
class ServerConfigService {
  static const String _keyServerHost = 'server_host';
  static const String _keyServerPort = 'server_port';

  // 直接使用 FlutterSecureStorage，不依赖 DI（启动阶段需要在 DI 初始化前使用）
  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
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
    String? host;
    int? port;

    try {
      host = await _storage.read(key: _keyServerHost);
    } catch (e) {
      debugPrint('ServerConfigService: Failed to read host from storage: $e');
    }

    try {
      final portStr = await _storage.read(key: _keyServerPort);
      if (portStr != null) {
        port = int.tryParse(portStr);
        // 验证端口范围
        if (!_isValidPort(port)) {
          debugPrint('ServerConfigService: Invalid port value $port, using default');
          port = null;
        }
      }
    } catch (e) {
      debugPrint('ServerConfigService: Failed to read port from storage: $e');
    }

    // 使用平台特定的默认主机地址（Android模拟器使用10.0.2.2）
    final defaultHost = NetworkConfig.getDefaultHostForPlatform();

    return (
      host: host ?? defaultHost,
      port: port ?? NetworkConfig.defaultServerPort,
    );
  }

  /// 保存服务器配置
  Future<void> saveConfig(String host, int port) async {
    // 验证端口范围
    if (!_isValidPort(port)) {
      throw ArgumentError('Port must be between 1 and 65535, got: $port');
    }
    await _storage.write(key: _keyServerHost, value: host);
    await _storage.write(key: _keyServerPort, value: port.toString());
  }

  /// 构建 API 基础 URL
  static String buildApiBaseUrl(String host, int port) {
    return 'http://$host:$port/api/v1';
  }
}
