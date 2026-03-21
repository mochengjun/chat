import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

/// 消息提示音服务
/// 
/// 负责在收到新消息时播放提示音，支持：
/// - 节流控制（避免短时间内大量消息连续播放）
/// - 静音模式开关
class NotificationSoundService {
  static final NotificationSoundService _instance = NotificationSoundService._internal();
  factory NotificationSoundService() => _instance;
  NotificationSoundService._internal();

  AudioPlayer? _audioPlayer;
  bool _isMuted = false;
  bool _isInitialized = false;
  DateTime? _lastPlayTime;
  static const Duration _throttleDuration = Duration(milliseconds: 800);

  /// 初始化服务
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // 配置音频会话，允许后台播放通知声音
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.sonification,
          usage: AndroidAudioUsage.notification,
          flags: AndroidAudioFlags.none,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
        androidWillPauseWhenDucked: false,
      ));
      
      _audioPlayer = AudioPlayer();
      // 设置音量为最大值
      await _audioPlayer?.setVolume(1.0);
      _isInitialized = true;
      print('NotificationSoundService initialized with audio session');
    } catch (e, stack) {
      print('NotificationSoundService initialize error: $e');
      print('Stack: $stack');
      // 音频初始化失败不影响应用运行
    }
  }

  /// 播放消息提示音
  /// 
  /// [force] 是否忽略节流限制强制播放
  Future<void> playMessageSound({bool force = false}) async {
    if (_isMuted) return;

    // 节流控制：避免短时间内重复播放
    if (!force && _lastPlayTime != null) {
      final elapsed = DateTime.now().difference(_lastPlayTime!);
      if (elapsed < _throttleDuration) {
        return;
      }
    }

    _lastPlayTime = DateTime.now();

    try {
      // 使用系统触觉反馈
      await HapticFeedback.mediumImpact();
      
      // 播放提示音
      await _playNotificationTone();
    } catch (e) {
      print('Play notification sound error: $e');
    }
  }

  /// 播放错误提示音（连接失败等）
  /// 
  /// 使用较低的音调和三连音来强调错误
  Future<void> playErrorSound() async {
    try {
      // 使用系统触觉反馈 - 连续两次强调错误
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.heavyImpact();
      
      // 播放错误提示音
      await _playErrorTone();
    } catch (e) {
      print('Play error sound error: $e');
    }
  }

  /// 播放错误提示音
  Future<void> _playErrorTone() async {
    try {
      // 确保初始化
      if (!_isInitialized || _audioPlayer == null) {
        await initialize();
      }
      
      final player = _audioPlayer;
      if (player == null) return;

      // 生成错误提示音 WAV 文件
      final wavBytes = _generateErrorWav();
      
      // 使用 StreamAudioSource 播放内存中的音频
      await player.setAudioSource(NotificationAudioSource(wavBytes));
      await player.seek(Duration.zero);
      await player.play();
      
    } catch (e) {
      print('Play error tone error: $e');
      // 备用方案：使用系统声音
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }

  /// 生成错误提示音 WAV 数据
  /// 生成三个较低音调的短促音，类似 "boop-boop-boop"
  Uint8List _generateErrorWav() {
    const int sampleRate = 44100;
    const int durationMs = 500; // 总时长 500ms
    const int numSamples = (sampleRate * durationMs) ~/ 1000;
    
    // WAV 文件头
    final header = ByteData(44);
    final dataSize = numSamples * 2; // 16-bit samples
    final fileSize = 36 + dataSize;
    
    // RIFF header
    header.setUint8(0, 0x52); // 'R'
    header.setUint8(1, 0x49); // 'I'
    header.setUint8(2, 0x46); // 'F'
    header.setUint8(3, 0x46); // 'F'
    header.setUint32(4, fileSize, Endian.little);
    header.setUint8(8, 0x57);  // 'W'
    header.setUint8(9, 0x41);  // 'A'
    header.setUint8(10, 0x56); // 'V'
    header.setUint8(11, 0x45); // 'E'
    
    // fmt chunk
    header.setUint8(12, 0x66); // 'f'
    header.setUint8(13, 0x6D); // 'm'
    header.setUint8(14, 0x74); // 't'
    header.setUint8(15, 0x20); // ' '
    header.setUint32(16, 16, Endian.little); // chunk size
    header.setUint16(20, 1, Endian.little);  // audio format (PCM)
    header.setUint16(22, 1, Endian.little);  // num channels (mono)
    header.setUint32(24, sampleRate, Endian.little); // sample rate
    header.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    header.setUint16(32, 2, Endian.little);  // block align
    header.setUint16(34, 16, Endian.little); // bits per sample
    
    // data chunk
    header.setUint8(36, 0x64); // 'd'
    header.setUint8(37, 0x61); // 'a'
    header.setUint8(38, 0x74); // 't'
    header.setUint8(39, 0x61); // 'a'
    header.setUint32(40, dataSize, Endian.little);
    
    // 生成音频数据 - 三个低音调短促音
    final samples = ByteData(dataSize);
    const double pi2 = 3.14159265359 * 2;
    
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      double sample = 0;
      
      // 第一个音调 (0-100ms): 330Hz (E4) - 低音
      if (t < 0.10) {
        final envelope = (1 - t / 0.10) * 1.0;
        sample = envelope * _sin(330 * pi2 * t);
      }
      // 第二个音调 (150-250ms): 294Hz (D4) - 更低
      else if (t >= 0.15 && t < 0.25) {
        final t2 = t - 0.15;
        final envelope = (1 - t2 / 0.10) * 1.0;
        sample = envelope * _sin(294 * pi2 * t2);
      }
      // 第三个音调 (300-400ms): 262Hz (C4) - 最低
      else if (t >= 0.30 && t < 0.40) {
        final t3 = t - 0.30;
        final envelope = (1 - t3 / 0.10) * 1.0;
        sample = envelope * _sin(262 * pi2 * t3);
      }
      
      // 转换为 16-bit 整数
      final intSample = (sample * 32767).round().clamp(-32768, 32767);
      samples.setInt16(i * 2, intSample, Endian.little);
    }
    
    // 合并文件头和数据
    final result = Uint8List(44 + dataSize);
    result.setAll(0, header.buffer.asUint8List());
    result.setAll(44, samples.buffer.asUint8List());
    
    return result;
  }

  /// 播放通知提示音
  Future<void> _playNotificationTone() async {
    try {
      // 确保初始化
      if (!_isInitialized || _audioPlayer == null) {
        await initialize();
      }
      
      final player = _audioPlayer;
      if (player == null) return;

      // 生成一个简单的通知音效 WAV 文件
      final wavBytes = _generateNotificationWav();
      
      // 使用 StreamAudioSource 播放内存中的音频
      await player.setAudioSource(NotificationAudioSource(wavBytes));
      await player.seek(Duration.zero);
      await player.play();
      
    } catch (e) {
      print('Play notification tone error: $e');
      // 备用方案：使用系统声音
      try {
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }

  /// 生成一个简单的通知提示音 WAV 数据
  /// 生成两个连续的短促音调，类似 "ding-ding"
  Uint8List _generateNotificationWav() {
    const int sampleRate = 44100;
    const int durationMs = 300; // 总时长 300ms
    const int numSamples = (sampleRate * durationMs) ~/ 1000;
    
    // WAV 文件头
    final header = ByteData(44);
    final dataSize = numSamples * 2; // 16-bit samples
    final fileSize = 36 + dataSize;
    
    // RIFF header
    header.setUint8(0, 0x52); // 'R'
    header.setUint8(1, 0x49); // 'I'
    header.setUint8(2, 0x46); // 'F'
    header.setUint8(3, 0x46); // 'F'
    header.setUint32(4, fileSize, Endian.little);
    header.setUint8(8, 0x57);  // 'W'
    header.setUint8(9, 0x41);  // 'A'
    header.setUint8(10, 0x56); // 'V'
    header.setUint8(11, 0x45); // 'E'
    
    // fmt chunk
    header.setUint8(12, 0x66); // 'f'
    header.setUint8(13, 0x6D); // 'm'
    header.setUint8(14, 0x74); // 't'
    header.setUint8(15, 0x20); // ' '
    header.setUint32(16, 16, Endian.little); // chunk size
    header.setUint16(20, 1, Endian.little);  // audio format (PCM)
    header.setUint16(22, 1, Endian.little);  // num channels (mono)
    header.setUint32(24, sampleRate, Endian.little); // sample rate
    header.setUint32(28, sampleRate * 2, Endian.little); // byte rate
    header.setUint16(32, 2, Endian.little);  // block align
    header.setUint16(34, 16, Endian.little); // bits per sample
    
    // data chunk
    header.setUint8(36, 0x64); // 'd'
    header.setUint8(37, 0x61); // 'a'
    header.setUint8(38, 0x74); // 't'
    header.setUint8(39, 0x61); // 'a'
    header.setUint32(40, dataSize, Endian.little);
    
    // 生成音频数据 - 两个短促的音调
    final samples = ByteData(dataSize);
    const double pi2 = 3.14159265359 * 2;
    
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      double sample = 0;
      
      // 第一个音调 (0-120ms): 880Hz (A5)
      if (t < 0.12) {
        final envelope = (1 - t / 0.12) * 1.0; // 渐弱
        sample = envelope * _sin(880 * pi2 * t);
      }
      // 第二个音调 (150-270ms): 1046Hz (C6)
      else if (t >= 0.15 && t < 0.27) {
        final t2 = t - 0.15;
        final envelope = (1 - t2 / 0.12) * 1.0; // 渐弱
        sample = envelope * _sin(1046 * pi2 * t2);
      }
      
      // 转换为 16-bit 整数
      final intSample = (sample * 32767).round().clamp(-32768, 32767);
      samples.setInt16(i * 2, intSample, Endian.little);
    }
    
    // 合并文件头和数据
    final result = Uint8List(44 + dataSize);
    result.setAll(0, header.buffer.asUint8List());
    result.setAll(44, samples.buffer.asUint8List());
    
    return result;
  }
  
  double _sin(double x) {
    // 简化的 sin 计算
    x = x % (3.14159265359 * 2);
    double result = x;
    double term = x;
    for (int i = 1; i < 10; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }

  /// 设置静音模式
  void setMuted(bool muted) {
    _isMuted = muted;
  }

  /// 获取静音状态
  bool get isMuted => _isMuted;

  /// 释放资源
  Future<void> dispose() async {
    await _audioPlayer?.dispose();
    _audioPlayer = null;
    _isInitialized = false;
  }
}

/// 自定义音频源，用于播放内存中的音频数据
class NotificationAudioSource extends StreamAudioSource {
  final Uint8List _buffer;
  
  NotificationAudioSource(this._buffer);
  
  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _buffer.length;
    
    return StreamAudioResponse(
      sourceLength: _buffer.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_buffer.sublist(start, end)),
      contentType: 'audio/wav',
    );
  }
}

/// 全局通知音服务实例
final notificationSoundService = NotificationSoundService();
