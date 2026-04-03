import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 性能优化工具类
class PerformanceOptimizer {
  static final PerformanceOptimizer _instance = PerformanceOptimizer._internal();
  factory PerformanceOptimizer() => _instance;
  PerformanceOptimizer._internal();

  /// 图片缓存大小配置
  static const int maxImageCacheSize = 100 * 1024 * 1024; // 100MB
  static const int maxImageCacheCount = 1000;

  /// 初始化性能优化配置
  static void init() {
    // 配置图片缓存
    final imageCache = PaintingBinding.instance.imageCache;
    imageCache.maximumSizeBytes = maxImageCacheSize;
    imageCache.maximumSize = maxImageCacheCount;
    
    debugPrint('[Performance] Image cache configured: $maxImageCacheSize bytes, $maxImageCacheCount items');
  }

  /// 清空图片缓存
  static void clearImageCache() {
    PaintingBinding.instance.imageCache.clear();
    debugPrint('[Performance] Image cache cleared');
  }

  /// 预加载图片
  static Future<void> precacheImages(
    BuildContext context,
    List<String> urls,
  ) async {
    for (final url in urls) {
      try {
        await precacheImage(
          NetworkImage(url),
          context,
        );
      } catch (e) {
        debugPrint('[Performance] Failed to precache image: $url');
      }
    }
    debugPrint('[Performance] Preloaded ${urls.length} images');
  }
}

/// 列表性能优化配置
class ListPerformanceConfig {
  /// 列表项缓存高度（用于 ListView.builder）
  final double? itemExtent;
  
  /// 是否使用 PrototypeItem（用于动态高度列表）
  final Widget? prototypeItem;
  
  /// 预缓存区域比例
  final double cacheExtent;

  const ListPerformanceConfig({
    this.itemExtent,
    this.prototypeItem,
    this.cacheExtent = 250,
  });
}

/// 消息列表优化配置
class MessageListOptimizer {
  /// 使用 ListView.builder 替代 ListView
  static ListView buildOptimizedListView({
    required int itemCount,
    required Widget Function(BuildContext, int) itemBuilder,
    ScrollController? controller,
    ListPerformanceConfig config = const ListPerformanceConfig(),
    bool reverse = false,
    EdgeInsetsGeometry? padding,
  }) {
    return ListView.builder(
      controller: controller,
      itemCount: itemCount,
      itemBuilder: itemBuilder,
      itemExtent: config.itemExtent,
      prototypeItem: config.prototypeItem,
      cacheExtent: config.cacheExtent,
      reverse: reverse,
      padding: padding,
      // 性能优化选项
      addAutomaticKeepAlives: true,
      addRepaintBoundaries: true,
      addSemanticIndexes: true,
    );
  }
}

/// 网络请求优化工具
class NetworkOptimizer {
  /// 请求缓存
  static final Map<String, _CacheEntry> _cache = {};
  
  /// 缓存持续时间（默认 5 分钟）
  static const Duration defaultCacheDuration = Duration(minutes: 5);

  /// 获取缓存数据（惰性清理过期条目）
  static T? getCached<T>(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    
    if (DateTime.now().isAfter(entry.expiryTime)) {
      _cache.remove(key);
      return null;
    }
    
    // 惰性清理：每次访问时清理过期条目
    _cleanupExpiredEntries();
    
    return entry.data as T?;
  }

  /// 设置缓存数据
  static void setCache<T>(String key, T data, {Duration? duration}) {
    _cache[key] = _CacheEntry(
      data: data,
      expiryTime: DateTime.now().add(duration ?? defaultCacheDuration),
    );
  }

  /// 清空缓存
  static void clearCache() {
    _cache.clear();
    debugPrint('[Performance] Network cache cleared');
  }

  /// 清理过期条目
  static void _cleanupExpiredEntries() {
    final now = DateTime.now();
    final expiredKeys = <String>[];
    
    for (final entry in _cache.entries) {
      if (now.isAfter(entry.value.expiryTime)) {
        expiredKeys.add(entry.key);
      }
    }
    
    for (final key in expiredKeys) {
      _cache.remove(key);
    }
    
    if (expiredKeys.isNotEmpty) {
      debugPrint('[Performance] Cleaned up ${expiredKeys.length} expired cache entries');
    }
  }

  /// 获取缓存统计
  static Map<String, dynamic> getCacheStats() {
    return {
      'count': _cache.length,
      'keys': _cache.keys.toList(),
    };
  }
}

class _CacheEntry {
  final dynamic data;
  final DateTime expiryTime;

  _CacheEntry({required this.data, required this.expiryTime});
}

/// 内存优化工具
class MemoryOptimizer {
  /// 手动触发 GC（仅在调试模式）
  static void triggerGC() {
    if (kDebugMode) {
      debugPrint('[Performance] GC triggered manually');
      // Flutter 没有直接的 GC API，但可以通过释放资源间接优化
    }
  }

  /// 获取内存使用情况
  static Future<Map<String, dynamic>> getMemoryUsage() async {
    // 在 Flutter 中获取内存信息需要平台特定实现
    // 这里提供占位符
    return {
      'platform': defaultTargetPlatform.toString(),
      'debugMode': kDebugMode,
    };
  }
}

/// Widget 重建优化工具
mixin RebuildOptimizer<T extends StatefulWidget> on State<T> {
  final Set<String> _rebuildReasons = {};
  
  /// 最大历史记录限制
  static const int maxHistorySize = 50;

  /// 记录重建原因
  void logRebuild(String reason) {
    if (kDebugMode) {
      // 如果超过最大限制，移除最早的记录
      if (_rebuildReasons.length >= maxHistorySize) {
        // Set 是无序的，转换为 List 后移除第一个
        final reasonsList = _rebuildReasons.toList();
        _rebuildReasons.clear();
        for (int i = 1; i < reasonsList.length; i++) {
          _rebuildReasons.add(reasonsList[i]);
        }
      }
      _rebuildReasons.add(reason);
      debugPrint('[Rebuild] ${widget.runtimeType}: $reason');
    }
  }

  /// 获取重建历史
  List<String> getRebuildHistory() {
    return _rebuildReasons.toList();
  }

  /// 清理重建历史
  void clearRebuildHistory() {
    _rebuildReasons.clear();
  }
}
