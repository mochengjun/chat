import 'dart:io' show Platform;
import 'package:connectivity_plus/connectivity_plus.dart';

/// 网络配置管理类
/// 集成ZeroTier网络配置、Docker代理设置、镜像加速器配置等
class NetworkConfig {
  // ZeroTier网络配置
  static const String zeroTierNetworkId = '6AB565387A193124';
  // 注意：如果ZeroTier IP变化，需要更新此配置
  // 当前实际IP: 172.25.194.201 (原: 172.25.118.254)
  static const String zeroTierGatewayIp = '172.25.194.201';
  static const int zeroTierUdpPort = 9993; // ZeroTier UDP通信端口（勿用作HTTP代理）

  // HTTP代理配置（独立于ZeroTier端口）
  static const int httpProxyPort = 8118; // 标准HTTP代理端口
  static const bool enableBuildProxy = false; // 构建时是否启用代理（默认禁用避免干扰）

  // Docker镜像加速器配置
  static const List<String> dockerMirrors = [
    'https://docker.mirrors.ustc.edu.cn',
    'https://hub-mirror.c.163.com',
    'https://mirror.baidubce.com'
  ];

  // 默认服务器配置
  // 使用实际检测到的IP地址，避免硬编码过时IP
  static const String defaultServerHost = '172.25.194.201';
  static const int defaultServerPort = 8081;
  
  // 网络检测相关
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration retryDelay = Duration(seconds: 3);
  static const int maxRetries = 3;
  
  // 构建网络弹性配置
  static const int buildNetworkRetries = 3;
  static const Duration buildNetworkTimeout = Duration(seconds: 60);

  /// 检测是否在Android模拟器中运行
  static bool get _isAndroidEmulator {
    if (!Platform.isAndroid) return false;
    // 通过检查特定属性来检测模拟器
    try {
      final product = Platform.environment['ANDROID_PRODUCT'] ?? '';
      final model = Platform.environment['ANDROID_MODEL'] ?? '';
      final device = Platform.environment['ANDROID_DEVICE'] ?? '';
      return product.contains('sdk') ||
          product.contains('emulator') ||
          model.contains('Emulator') ||
          model.contains('Android SDK') ||
          device.contains('emulator');
    } catch (_) {
      return false;
    }
  }

  /// 获取API基础URL
  static String getApiBaseUrl({String? overrideHost, int? overridePort}) {
    final host = overrideHost ?? defaultServerHost;
    final port = overridePort ?? defaultServerPort;

    if (Platform.isAndroid) {
      // Android模拟器使用10.0.2.2访问宿主机
      // Android真机使用配置的IP
      final androidHost = _isAndroidEmulator ? '10.0.2.2' : host;
      return 'http://$androidHost:$port/api/v1';
    } else if (Platform.isIOS) {
      // iOS模拟器使用localhost/127.0.0.1访问宿主机
      // iOS真机使用配置的IP
      final iosHost = _isAndroidEmulator ? 'localhost' : host;
      return 'http://$iosHost:$port/api/v1';
    }
    // 桌面平台使用ZeroTier网络IP
    return 'http://$host:$port/api/v1';
  }

  /// 获取适用于当前平台的默认主机地址
  static String getDefaultHostForPlatform() {
    if (Platform.isAndroid) {
      // Android模拟器使用10.0.2.2
      return _isAndroidEmulator ? '10.0.2.2' : defaultServerHost;
    } else if (Platform.isIOS) {
      // iOS模拟器使用localhost
      return _isAndroidEmulator ? 'localhost' : defaultServerHost;
    }
    return defaultServerHost;
  }

  /// 检查是否在ZeroTier网络中
  static Future<bool> isInZeroTierNetwork() async {
    try {
      final connectivity = Connectivity();
      await connectivity.checkConnectivity();
      
      // 这里需要实际检查网络接口
      // 暂时返回true，实际实现需要检查网络接口
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 获取Docker代理配置（仅在enableBuildProxy为true时使用）
  static String? getDockerProxyConfig() {
    if (!enableBuildProxy) return null;
    return 'http://$zeroTierGatewayIp:$httpProxyPort';
  }

  /// 获取镜像加速器列表
  static List<String> getDockerMirrors() {
    return dockerMirrors;
  }
}