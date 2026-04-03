import 'package:flutter_test/flutter_test.dart';
import 'package:sec_chat/core/network/network_config.dart';

void main() {
  group('NetworkConfig', () {
    test('defaultServerHost should not be empty', () {
      expect(NetworkConfig.defaultServerHost, isNotEmpty);
    });

    test('defaultServerPort should be positive', () {
      expect(NetworkConfig.defaultServerPort, greaterThan(0));
    });

    test('getDefaultHostForPlatform should return non-empty host', () {
      // 在 Windows 测试环境中，应返回默认服务器地址
      final host = NetworkConfig.getDefaultHostForPlatform();
      expect(host, isNotEmpty);
      expect(host, equals(NetworkConfig.defaultServerHost));
    });

    test('getApiBaseUrl should construct valid URL on desktop', () {
      final url = NetworkConfig.getApiBaseUrl();
      expect(url, contains('http://'));
      expect(url, contains('/api/v1'));
      expect(url, contains(NetworkConfig.defaultServerHost));
    });

    test('getApiBaseUrl should respect overrideHost', () {
      final url = NetworkConfig.getApiBaseUrl(overrideHost: '10.0.0.1');
      expect(url, contains('10.0.0.1'));
      expect(url, contains('/api/v1'));
    });

    test('getApiBaseUrl should respect overridePort', () {
      final url = NetworkConfig.getApiBaseUrl(overridePort: 9999);
      expect(url, contains(':9999'));
    });

    test('getApiBaseUrl with both overrides', () {
      final url = NetworkConfig.getApiBaseUrl(
        overrideHost: 'myserver.local',
        overridePort: 3001,
      );
      expect(url, equals('http://myserver.local:3001/api/v1'));
    });

    test('connectionTimeout should be reasonable', () {
      expect(
        NetworkConfig.connectionTimeout.inSeconds,
        greaterThanOrEqualTo(5),
      );
    });
  });
}
