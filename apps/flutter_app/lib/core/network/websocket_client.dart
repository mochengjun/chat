import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../services/notification_sound_service.dart';

/// WebSocket 连接状态
enum WebSocketConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed,
}

class WebSocketClient {
  final String baseUrl;
  final String Function() tokenProvider;

  // 设备ID管理 - 使用与 SecureStorageService 相同的配置避免崩溃
  static final _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: false,
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_PKCS1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_CBC_PKCS7Padding,
    ),
  );
  static const _deviceIdKey = 'sec_chat_device_id';
  static String? _cachedDeviceId;
  
  WebSocketChannel? _channel;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectionStateController = StreamController<WebSocketConnectionState>.broadcast();
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  int _reconnectAttempts = 0;
  static const _maxReconnectAttempts = 5;
  static const _reconnectDelay = Duration(seconds: 3);
  static const _heartbeatInterval = Duration(seconds: 30);
  WebSocketConnectionState _connectionState = WebSocketConnectionState.disconnected;
  bool _hasPlayedFinalErrorSound = false;

  WebSocketClient({
    required this.baseUrl,
    required this.tokenProvider,
  });

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<WebSocketConnectionState> get connectionStateStream => _connectionStateController.stream;
  bool get isConnected => _isConnected;
  WebSocketConnectionState get connectionState => _connectionState;

  void _updateConnectionState(WebSocketConnectionState state, {String? errorMessage}) {
    _connectionState = state;
    _connectionStateController.add(state);
    
    // 只在最终失败状态时播放错误提示音（达到最大重连次数后）
    // 且只播放一次，避免重复提示音
    if (state == WebSocketConnectionState.failed && 
        _reconnectAttempts >= _maxReconnectAttempts && 
        !_hasPlayedFinalErrorSound) {
      _hasPlayedFinalErrorSound = true;
      notificationSoundService.playErrorSound();
      print('WebSocket 连接最终失败: $errorMessage');
    }
  }

  /// 获取或生成唯一的设备ID
  Future<String> _getDeviceId() async {
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }
    
    var deviceId = await _storage.read(key: _deviceIdKey);
    if (deviceId == null) {
      // 生成唯一的设备ID
      final platform = Platform.isIOS ? 'ios' : Platform.isAndroid ? 'android' : 'desktop';
      deviceId = '${platform}_${DateTime.now().millisecondsSinceEpoch}';
      await _storage.write(key: _deviceIdKey, value: deviceId);
    }
    _cachedDeviceId = deviceId;
    return deviceId;
  }

  Future<void> connect() async {
    if (_isConnected) return;
    
    _updateConnectionState(WebSocketConnectionState.connecting);
    
    try {
      final token = tokenProvider();
      final deviceId = await _getDeviceId();
      final wsUrl = baseUrl.replaceFirst('http', 'ws');
      final uri = Uri.parse('$wsUrl/ws?token=$token&device_id=${Uri.encodeComponent(deviceId)}');
      
      _channel = WebSocketChannel.connect(uri);
      _isConnected = true;
      _reconnectAttempts = 0;
      _hasPlayedFinalErrorSound = false; // 连接成功时重置错误提示音标志
      _updateConnectionState(WebSocketConnectionState.connected);
      
      _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
      );
      
      _startHeartbeat();
    } catch (e) {
      _isConnected = false;
      _updateConnectionState(WebSocketConnectionState.failed, errorMessage: e.toString());
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic data) {
    try {
      final message = jsonDecode(data as String) as Map<String, dynamic>;
      
      if (message['type'] == 'pong') {
        return;
      }
      
      _messageController.add(message);
    } catch (_) {}
  }

  void _onError(dynamic error) {
    _isConnected = false;
    _updateConnectionState(WebSocketConnectionState.failed, errorMessage: error.toString());
    _scheduleReconnect();
  }

  void _onDone() {
    _isConnected = false;
    _stopHeartbeat();
    if (_reconnectAttempts < _maxReconnectAttempts) {
      _updateConnectionState(WebSocketConnectionState.reconnecting);
    } else {
      _updateConnectionState(WebSocketConnectionState.disconnected);
    }
    _scheduleReconnect();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      send({'type': 'ping'});
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      // 达到最大重连次数，播放错误提示音
      _updateConnectionState(WebSocketConnectionState.failed, 
        errorMessage: '无法连接到服务器，请检查网络或重开ZeroTier');
      return;
    }
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () {
      _reconnectAttempts++;
      _updateConnectionState(WebSocketConnectionState.reconnecting);
      connect();
    });
  }

  void send(Map<String, dynamic> data) {
    if (_isConnected && _channel != null) {
      _channel!.sink.add(jsonEncode(data));
    }
  }

  Future<void> disconnect() async {
    _stopHeartbeat();
    _reconnectTimer?.cancel();
    _isConnected = false;
    _reconnectAttempts = 0; // 重置重连次数
    _hasPlayedFinalErrorSound = false; // 重置错误提示音标志
    _updateConnectionState(WebSocketConnectionState.disconnected);
    await _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
    _connectionStateController.close();
  }
}
