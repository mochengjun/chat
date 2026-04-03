import 'package:flutter_test/flutter_test.dart';
import 'package:sec_chat/core/network/server_config_service.dart';
import 'package:sec_chat/core/network/network_config.dart';

void main() {
  group('ServerConfigService', () {
    test('buildApiBaseUrl should construct correct URL', () {
      final url = ServerConfigService.buildApiBaseUrl('192.168.1.100', 3000);
      expect(url, equals('http://192.168.1.100:3000/api/v1'));
    });

    test('buildApiBaseUrl should handle default server config', () {
      final url = ServerConfigService.buildApiBaseUrl(
        NetworkConfig.defaultServerHost,
        NetworkConfig.defaultServerPort,
      );
      expect(url, equals('http://${NetworkConfig.defaultServerHost}:${NetworkConfig.defaultServerPort}/api/v1'));
    });

    test('buildApiBaseUrl should handle localhost', () {
      final url = ServerConfigService.buildApiBaseUrl('localhost', 8080);
      expect(url, equals('http://localhost:8080/api/v1'));
    });

    test('buildApiBaseUrl should handle 10.0.2.2 for Android emulator', () {
      final url = ServerConfigService.buildApiBaseUrl('10.0.2.2', 80);
      expect(url, equals('http://10.0.2.2:80/api/v1'));
    });

    test('loadConfig should return valid config without throwing', () async {
      // loadConfig 内部有 try-catch，即使存储操作失败也应返回默认值
      final config = await ServerConfigService.loadConfig();
      expect(config.host, isNotEmpty);
      expect(config.port, greaterThan(0));
    });
  });
}
