import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/security/secure_storage.dart';
import '../../../../core/network/server_config_service.dart';

/// 获取认证headers
Future<Map<String, String>> getAuthHeaders() async {
  try {
    final storage = getIt<SecureStorageService>();
    final token = await storage.getAccessToken();
    final headers = <String, String>{};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  } catch (e) {
    debugPrint('[AuthImage] getAuthHeaders error: $e');
    return <String, String>{};
  }
}

/// 获取当前用户ID用于缓存key
Future<String> _getCacheKeySuffix() async {
  try {
    final storage = getIt<SecureStorageService>();
    final userInfo = await storage.getUserInfo();
    return userInfo['userId'] ?? 'anonymous';
  } catch (e) {
    debugPrint('[AuthImage] _getCacheKeySuffix error: $e');
    return 'anonymous';
  }
}

/// 获取完整的图片URL
Future<String> getFullImageUrl(String? url) async {
  if (url == null || url.isEmpty) return '';
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return url;
  }
  try {
    final config = await ServerConfigService.loadConfig();
    // 检查 URL 是否已经包含 /api/v1 前缀，避免重复添加
    if (url.startsWith('/api/v1/')) {
      final hostUrl = 'http://${config.host}:${config.port}';
      return '$hostUrl$url';
    }
    final baseUrl = ServerConfigService.buildApiBaseUrl(config.host, config.port);
    return '$baseUrl$url';
  } catch (e) {
    debugPrint('[AuthImage] getFullImageUrl error: $e, url=$url');
    return '';
  }
}

/// 支持认证的网络图片组件
class AuthNetworkImage extends StatefulWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final String? thumbnailUrl;

  const AuthNetworkImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.contain, // 使用 contain 保持图片比例，避免拉伸
    this.placeholder,
    this.errorWidget,
    this.thumbnailUrl,
  });

  @override
  State<AuthNetworkImage> createState() => _AuthNetworkImageState();
}

class _AuthNetworkImageState extends State<AuthNetworkImage> {
  Map<String, String> _headers = {};
  String _fullUrl = '';
  String? _thumbnailUrl;
  String _cacheKeySuffix = '';
  bool _isInitialized = false; // 标记是否已完成初始化

  @override
  void initState() {
    super.initState();
    _loadHeaders();
  }

  @override
  void didUpdateWidget(AuthNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl || oldWidget.thumbnailUrl != widget.thumbnailUrl) {
      _loadHeaders();
    }
  }

  Future<void> _loadHeaders() async {
    _isInitialized = false;
    try {
      _headers = await getAuthHeaders();
      if (!mounted) return;
      _fullUrl = await getFullImageUrl(widget.imageUrl);
      if (!mounted) return;
      _thumbnailUrl = widget.thumbnailUrl != null ? await getFullImageUrl(widget.thumbnailUrl) : null;
      if (!mounted) return;
      _cacheKeySuffix = await _getCacheKeySuffix();
    } catch (e) {
      debugPrint('[AuthNetworkImage] _loadHeaders error: $e');
      _fullUrl = '';
    }
    if (mounted) {
      _isInitialized = true;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    // 在初始化完成之前显示加载状态
    if (!_isInitialized) {
      return widget.placeholder ?? Container(
        width: widget.width,
        height: widget.height,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_fullUrl.isEmpty) {
      return widget.errorWidget ?? _buildDefaultErrorWidget();
    }

    final displayUrl = _thumbnailUrl ?? _fullUrl;
    // 使用用户ID作为缓存key的一部分，确保不同用户的缓存不会混淆
    final cacheKey = '$_cacheKeySuffix:$displayUrl';

    return CachedNetworkImage(
      imageUrl: displayUrl,
      cacheKey: cacheKey, // 自定义缓存key，包含用户ID
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      httpHeaders: _headers,
      // 禁用内存缓存，避免认证问题
      memCacheWidth: null,
      memCacheHeight: null,
      placeholder: widget.placeholder != null
          ? (context, url) => widget.placeholder!
          : (context, url) => Container(
              width: widget.width,
              height: widget.height,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
      errorWidget: widget.errorWidget != null
          ? (context, url, error) => widget.errorWidget!
          : (context, url, error) {
              debugPrint('[AuthNetworkImage] CachedNetworkImage error: $error, url: $url');
              return _buildDefaultErrorWidget();
            },
    );
  }

  Widget _buildDefaultErrorWidget() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Theme.of(context).colorScheme.errorContainer,
      child: Center(
        child: Icon(
          Icons.broken_image,
          color: Theme.of(context).colorScheme.onErrorContainer,
          size: 32,
        ),
      ),
    );
  }
}

/// 支持认证的图片查看器（支持缩放和平移）
class AuthPhotoView extends StatefulWidget {
  final String? imageUrl;
  final String? thumbnailUrl;
  final Widget? loadingBuilder;
  final Widget? errorBuilder;
  final Color? backgroundColor;

  const AuthPhotoView({
    super.key,
    required this.imageUrl,
    this.thumbnailUrl,
    this.loadingBuilder,
    this.errorBuilder,
    this.backgroundColor,
  });

  @override
  State<AuthPhotoView> createState() => _AuthPhotoViewState();
}

class _AuthPhotoViewState extends State<AuthPhotoView> {
  Map<String, String> _headers = {};
  String _fullUrl = '';
  String _cacheKeySuffix = '';
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadHeaders();
  }

  @override
  void didUpdateWidget(AuthPhotoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadHeaders();
    }
  }

  Future<void> _loadHeaders() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      _headers = await getAuthHeaders();
      if (!mounted) return;
      _fullUrl = await getFullImageUrl(widget.imageUrl);
      if (!mounted) return;
      _cacheKeySuffix = await _getCacheKeySuffix();
    } catch (e) {
      debugPrint('[AuthPhotoView] _loadHeaders error: $e');
      _fullUrl = '';
      _hasError = true;
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.loadingBuilder ?? const Center(child: CircularProgressIndicator());
    }

    if (_fullUrl.isEmpty || _hasError) {
      return widget.errorBuilder ?? Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image, size: 64, color: Colors.white54),
            const SizedBox(height: 16),
            const Text('图片加载失败', style: TextStyle(color: Colors.white54)),
          ],
        ),
      );
    }

    // 使用用户ID作为缓存key的一部分，确保不同用户的缓存不会混淆
    final cacheKey = '$_cacheKeySuffix:$_fullUrl';

    return PhotoView(
      imageProvider: CachedNetworkImageProvider(
        _fullUrl,
        headers: _headers,
        cacheKey: cacheKey, // 自定义缓存key，包含用户ID
      ),
      backgroundDecoration: BoxDecoration(
        color: widget.backgroundColor ?? Colors.black,
      ),
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 4.0,
      // 使用 covered 作为初始缩放，让图片填满屏幕宽度，消除两侧黑边
      initialScale: PhotoViewComputedScale.covered,
      filterQuality: FilterQuality.high,
      loadingBuilder: (context, event) {
        return widget.loadingBuilder ?? Center(
          child: CircularProgressIndicator(
            value: event?.expectedTotalBytes != null
                ? event!.cumulativeBytesLoaded / event.expectedTotalBytes!
                : null,
            color: Colors.white,
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        debugPrint('[AuthPhotoView] PhotoView error: $error');
        return widget.errorBuilder ?? Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.broken_image, size: 64, color: Colors.white54),
              const SizedBox(height: 16),
              const Text('图片加载失败', style: TextStyle(color: Colors.white54)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _hasError = false;
                    _isLoading = true;
                  });
                  _loadHeaders();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ),
        );
      },
    );
  }
}
