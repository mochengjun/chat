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

  /// 加载服务器配置（静态方法，可在 DI 初始化前调用）
  /// 若无存储值，返回 NetworkConfig 中的平台特定默认值
  static Future<({String host, int port})> loadConfig() async {
    final host = await _storage.read(key: _keyServerHost);
    final portStr = await _storage.read(key: _keyServerPort);
    final port = portStr != null ? int.tryParse(portStr) : null;

    // 使用平台特定的默认主机地址（Android模拟器使用10.0.2.2）
    final defaultHost = NetworkConfig.getDefaultHostForPlatform();

    return (
      host: host ?? defaultHost,
      port: port ?? NetworkConfig.defaultServerPort,
    );
  }

  /// 保存服务器配置
  Future<void> saveConfig(String host, int port) async {
    await _storage.write(key: _keyServerHost, value: host);
    await _storage.write(key: _keyServerPort, value: port.toString());
  }

  /// 构建 API 基础 URL
  static String buildApiBaseUrl(String host, int port) {
    return 'http://$host:$port/api/v1';
  }
}
