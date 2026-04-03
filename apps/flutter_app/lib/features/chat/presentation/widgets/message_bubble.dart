import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/entities/message.dart';
import '../utils/time_utils.dart';
import 'auth_image.dart';

class MessageBubble extends StatefulWidget {
  final Message message;
  final bool isMe;
  final bool showSender;
  final VoidCallback? onLongPress;
  final VoidCallback? onRetry;
  final VoidCallback? onMediaTap;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.showSender = false,
    this.onLongPress,
    this.onRetry,
    this.onMediaTap,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  Timer? _countdownTimer;
  Duration? _remainingTime;

  @override
  void initState() {
    super.initState();
    _startCountdownIfNeeded();
  }

  @override
  void didUpdateWidget(MessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.autoDeleteAt != widget.message.autoDeleteAt) {
      _countdownTimer?.cancel();
      _startCountdownIfNeeded();
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdownIfNeeded() {
    if (widget.message.autoDeleteAt != null && !widget.message.isDeleted) {
      _updateRemainingTime();
      _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (!mounted) {
          _countdownTimer?.cancel();
          return;
        }
        _updateRemainingTime();
      });
    }
  }

  void _updateRemainingTime() {
    if (widget.message.autoDeleteAt != null) {
      final now = DateTime.now();
      final remaining = widget.message.autoDeleteAt!.difference(now);
      if (mounted) {
        setState(() {
          _remainingTime = remaining.isNegative ? Duration.zero : remaining;
        });
      }
    }
  }

  String _formatRemainingTime() {
    if (_remainingTime == null) return '';
    if (_remainingTime!.inSeconds <= 0) return '即将撤回';
    
    if (_remainingTime!.inHours > 0) {
      return '${_remainingTime!.inHours}小时后撤回';
    } else if (_remainingTime!.inMinutes > 0) {
      return '${_remainingTime!.inMinutes}分钟后撤回';
    } else {
      return '${_remainingTime!.inSeconds}秒后撤回';
    }
  }

  /// 检测是否为桌面平台 (Windows, macOS, Linux)
  bool get _isDesktop {
    if (kIsWeb) return false;
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 其他人的消息：发言人信息显示在左侧（头像 + 姓名）
          if (!widget.isMe) ...[
            _buildAvatar(theme),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // 姓名显示（仅群组聊天时显示）
                if (widget.showSender && !widget.isMe)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      widget.message.senderName,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                // 时间显示在消息气泡上方
                _buildTimeRow(theme),
                const SizedBox(height: 4),
                // 消息气泡 - 桌面平台使用右键菜单，移动平台使用长按
                _buildMessageBubble(context, theme),
              ],
            ),
          ),
          // 我的消息：发言人信息显示在右侧（头像）
          if (widget.isMe) ...[
            const SizedBox(width: 8),
            _buildAvatar(theme),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, ThemeData theme) {
    final bubbleContent = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: widget.isMe
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(widget.isMe ? 16 : 4),
          bottomRight: Radius.circular(widget.isMe ? 4 : 16),
        ),
      ),
      child: _buildContent(theme),
    );

    // 桌面平台：使用右键菜单，不干扰文本选择
    if (_isDesktop) {
      return GestureDetector(
        onSecondaryTapUp: (details) {
          // 右键点击显示菜单
          widget.onLongPress?.call();
        },
        child: bubbleContent,
      );
    }

    // 移动平台：保持长按手势
    return GestureDetector(
      onLongPress: widget.onLongPress,
      child: bubbleContent,
    );
  }

  Widget _buildTimeRow(ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: _formatDetailedTime(),
          preferBelow: false,
          child: Text(
            _formatTime(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ),
        // 显示定时撤回倒计时
        if (widget.message.autoDeleteAt != null && !widget.message.isDeleted) ...[
          const SizedBox(width: 6),
          Icon(
            Icons.timer_outlined,
            size: 12,
            color: theme.colorScheme.tertiary,
          ),
          const SizedBox(width: 2),
          Text(
            _formatRemainingTime(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.tertiary,
              fontSize: 10,
            ),
          ),
        ],
        if (widget.isMe) ...[
          const SizedBox(width: 4),
          _buildStatusIcon(theme),
        ],
      ],
    );
  }

  Widget _buildAvatar(ThemeData theme) {
    if (widget.message.senderAvatar != null && widget.message.senderAvatar!.isNotEmpty) {
      return ClipOval(
        child: AuthNetworkImage(
          imageUrl: widget.message.senderAvatar,
          width: 32,
          height: 32,
          fit: BoxFit.cover,
          placeholder: CircleAvatar(
            radius: 16,
            backgroundColor: theme.colorScheme.secondaryContainer,
            child: Text(
              widget.message.senderName.isNotEmpty ? widget.message.senderName[0].toUpperCase() : '?',
              style: TextStyle(
                color: theme.colorScheme.onSecondaryContainer,
                fontSize: 12,
              ),
            ),
          ),
          errorWidget: CircleAvatar(
            radius: 16,
            backgroundColor: theme.colorScheme.secondaryContainer,
            child: Text(
              widget.message.senderName.isNotEmpty ? widget.message.senderName[0].toUpperCase() : '?',
              style: TextStyle(
                color: theme.colorScheme.onSecondaryContainer,
                fontSize: 12,
              ),
            ),
          ),
        ),
      );
    }
    
    return CircleAvatar(
      radius: 16,
      backgroundColor: theme.colorScheme.secondaryContainer,
      child: Text(
        widget.message.senderName.isNotEmpty ? widget.message.senderName[0].toUpperCase() : '?',
        style: TextStyle(
          color: theme.colorScheme.onSecondaryContainer,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    final textColor = widget.isMe
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;
    
    switch (widget.message.type) {
      case MessageType.image:
        return _buildImageContent(theme);
      case MessageType.video:
        return _buildVideoContent(theme, textColor);
      case MessageType.audio:
        return _buildAudioContent(theme, textColor);
      case MessageType.file:
        return _buildFileContent(theme, textColor);
      case MessageType.system:
        return _buildSystemContent(theme);
      default:
        // 桌面平台使用 SelectableText 支持鼠标选择复制
        if (_isDesktop) {
          return SelectableText(
            widget.message.content,
            style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
            // 自定义选择菜单 - 显示中文 "复制" 选项
            contextMenuBuilder: (context, editableTextState) {
              final TextEditingValue value = editableTextState.textEditingValue;
              final bool hasSelection = value.selection.isValid &&
                  !value.selection.isCollapsed;
              
              return AdaptiveTextSelectionToolbar(
                anchors: editableTextState.contextMenuAnchors,
                children: [
                  // 复制按钮（仅在有选中文本时显示）
                  if (hasSelection)
                    TextSelectionToolbarTextButton(
                      padding: const EdgeInsets.all(8.0),
                      onPressed: () {
                        final selectedText = value.selection.textInside(value.text);
                        Clipboard.setData(ClipboardData(text: selectedText));
                        editableTextState.hideToolbar();
                      },
                      child: const Text('复制'),
                    ),
                  // 全选按钮
                  TextSelectionToolbarTextButton(
                    padding: const EdgeInsets.all(8.0),
                    onPressed: () {
                      editableTextState.selectAll(SelectionChangedCause.toolbar);
                    },
                    child: const Text('全选'),
                  ),
                ],
              );
            },
          );
        }
        // 移动平台使用普通 Text
        return Text(
          widget.message.content,
          style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
        );
    }
  }

  Widget _buildImageContent(ThemeData theme) {
    if (widget.message.mediaUrl != null) {
      return GestureDetector(
        onTap: widget.onMediaTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 200,
              maxHeight: 300,
            ),
            child: AuthNetworkImage(
              imageUrl: widget.message.mediaUrl,
              thumbnailUrl: widget.message.thumbnailUrl,
              fit: BoxFit.contain, // 使用 contain 保持图片原始比例
              placeholder: Container(
                color: theme.colorScheme.surfaceContainerHighest,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              errorWidget: Container(
                color: theme.colorScheme.errorContainer,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.broken_image,
                      color: theme.colorScheme.onErrorContainer,
                      size: 32,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '加载失败',
                      style: TextStyle(
                        color: theme.colorScheme.onErrorContainer,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Text(
      '[图片]',
      style: theme.textTheme.bodyMedium?.copyWith(
        color: widget.isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
      ),
    );
  }

  Widget _buildVideoContent(ThemeData theme, Color textColor) {
    return GestureDetector(
      onTap: widget.onMediaTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.videocam, color: textColor, size: 20),
          const SizedBox(width: 8),
          Text(
            widget.message.content.isNotEmpty ? widget.message.content : '[视频]',
            style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioContent(ThemeData theme, Color textColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.mic, color: textColor, size: 20),
        const SizedBox(width: 8),
        Text(
          widget.message.content.isNotEmpty ? widget.message.content : '[语音]',
          style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
        ),
      ],
    );
  }

  Widget _buildFileContent(ThemeData theme, Color textColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.attach_file, color: textColor, size: 20),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            widget.message.content.isNotEmpty ? widget.message.content : '[文件]',
            style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildSystemContent(ThemeData theme) {
    return Text(
      widget.message.content,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.outline,
        fontStyle: FontStyle.italic,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildStatusIcon(ThemeData theme) {
    switch (widget.message.status) {
      case MessageStatus.sending:
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: theme.colorScheme.outline,
          ),
        );
      case MessageStatus.sent:
        return Icon(
          Icons.check,
          size: 14,
          color: theme.colorScheme.outline,
        );
      case MessageStatus.delivered:
        return Icon(
          Icons.done_all,
          size: 14,
          color: theme.colorScheme.outline,
        );
      case MessageStatus.read:
        return Icon(
          Icons.done_all,
          size: 14,
          color: theme.colorScheme.primary,
        );
      case MessageStatus.failed:
        return GestureDetector(
          onTap: widget.onRetry,
          child: Icon(
            Icons.error_outline,
            size: 14,
            color: theme.colorScheme.error,
          ),
        );
    }
  }

  String _formatTime() {
    return TimeUtils.formatLocalTime(widget.message.createdAt);
  }

  String _formatDetailedTime() {
    return TimeUtils.formatDetailedTime(widget.message.createdAt);
  }
}
