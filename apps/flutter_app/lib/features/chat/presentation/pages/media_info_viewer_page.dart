import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/services/media_service.dart';
import '../widgets/auth_image.dart';

/// 媒体信息查看器页面 - 用于从MediaInfo对象显示图片
class MediaInfoViewerPage extends StatefulWidget {
  final MediaInfo media;
  final List<MediaInfo>? mediaList; // 支持浏览多个媒体

  const MediaInfoViewerPage({
    super.key,
    required this.media,
    this.mediaList,
  });

  @override
  State<MediaInfoViewerPage> createState() => _MediaInfoViewerPageState();
}

class _MediaInfoViewerPageState extends State<MediaInfoViewerPage> {
  bool _showControls = true;
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = _findInitialIndex();
    _pageController = PageController(initialPage: _currentIndex);
    // 全屏模式
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  int _findInitialIndex() {
    if (widget.mediaList == null) return 0;
    final index = widget.mediaList!.indexWhere((m) => m.id == widget.media.id);
    return index >= 0 ? index : 0;
  }

  @override
  void dispose() {
    _pageController.dispose();
    // 恢复系统UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  MediaInfo get _currentMedia {
    if (widget.mediaList != null && widget.mediaList!.isNotEmpty) {
      return widget.mediaList![_currentIndex];
    }
    return widget.media;
  }

  @override
  Widget build(BuildContext context) {
    final isMultipleMode = widget.mediaList != null && widget.mediaList!.length > 1;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 媒体内容
          GestureDetector(
            onTap: _toggleControls,
            child: isMultipleMode
                ? PageView.builder(
                    controller: _pageController,
                    itemCount: widget.mediaList!.length,
                    onPageChanged: (index) {
                      setState(() => _currentIndex = index);
                    },
                    itemBuilder: (context, index) {
                      return Center(
                        child: _buildMediaContent(widget.mediaList![index]),
                      );
                    },
                  )
                : Center(
                    child: _buildMediaContent(widget.media),
                  ),
          ),

          // 顶部控制栏
          if (_showControls)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentMedia.originalName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _formatFileSize(_currentMedia.size),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.download, color: Colors.white),
                        onPressed: () => _downloadMedia(context),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        onSelected: (value) => _handleMenuAction(context, value),
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'save',
                            child: ListTile(
                              leading: Icon(Icons.save_alt),
                              title: Text('保存到相册'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'share',
                            child: ListTile(
                              leading: Icon(Icons.share),
                              title: Text('分享'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 底部控制栏
          if (_showControls)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 多图浏览指示器
                        if (isMultipleMode) ...[
                          Text(
                            '${_currentIndex + 1} / ${widget.mediaList!.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        const Text(
                          '双击放大 · 双指缩放 · 拖拽移动',
                          style: TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMediaContent(MediaInfo media) {
    switch (media.mediaType) {
      case MediaType.image:
        return _buildImageViewer(media);
      case MediaType.video:
        return _buildVideoPlayer(media);
      default:
        return _buildUnsupportedContent(media);
    }
  }

  Widget _buildImageViewer(MediaInfo media) {
    final imageUrl = media.downloadUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      return _buildPlaceholder(Icons.broken_image, '图片无法加载');
    }

    return AuthPhotoView(
      imageUrl: imageUrl,
      thumbnailUrl: media.thumbnailUrl,
      loadingBuilder: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 12),
            const Text(
              '加载中...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
      errorBuilder: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image, size: 64, color: Colors.white54),
            const SizedBox(height: 16),
            const Text('图片加载失败', style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                // 触发重新加载
                setState(() {});
              },
              icon: const Icon(Icons.refresh),
              label: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer(MediaInfo media) {
    // 视频播放器占位
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.play_circle_outline,
          size: 80,
          color: Colors.white,
        ),
        const SizedBox(height: 16),
        Text(
          media.originalName,
          style: const TextStyle(color: Colors.white70),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => _downloadMedia(context),
          icon: const Icon(Icons.download),
          label: const Text('下载视频'),
        ),
      ],
    );
  }

  Widget _buildUnsupportedContent(MediaInfo media) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.insert_drive_file, size: 64, color: Colors.white54),
        const SizedBox(height: 16),
        Text(
          media.originalName,
          style: const TextStyle(color: Colors.white54, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          _formatFileSize(media.size),
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => _downloadMedia(context),
          icon: const Icon(Icons.download),
          label: const Text('下载文件'),
        ),
      ],
    );
  }

  Widget _buildPlaceholder(IconData icon, String text) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 64, color: Colors.white54),
        const SizedBox(height: 16),
        Text(
          text,
          style: const TextStyle(color: Colors.white54, fontSize: 16),
        ),
      ],
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }

  void _downloadMedia(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('正在下载: ${_currentMedia.originalName}')),
    );
    // TODO: 实现下载逻辑
  }

  void _handleMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'save':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('正在保存到相册...')),
        );
        // TODO: 实现保存到相册逻辑
        break;
      case 'share':
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('分享功能开发中')),
        );
        break;
    }
  }
}
