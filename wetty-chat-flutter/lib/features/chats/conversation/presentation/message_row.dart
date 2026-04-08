import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:go_router/go_router.dart';

import '../../../../app/routing/route_names.dart';
import '../../../../app/theme/style_config.dart';
import '../../../../core/network/api_config.dart';
import '../../models/message_models.dart';
import '../domain/conversation_message.dart';
import 'message_avatar.dart';
import 'message_bubble/message_bubble.dart';
import 'message_bubble/message_bubble_presentation.dart';
import 'video_popup_player.dart';

class MessageLongPressDetails {
  const MessageLongPressDetails({
    required this.message,
    required this.bubbleRect,
    required this.isMe,
    Rect? visibleRect,
  }) : visibleRect = visibleRect ?? bubbleRect;

  MessageLongPressDetails copyWith({
    ConversationMessage? message,
    Rect? bubbleRect,
    bool? isMe,
    Rect? visibleRect,
  }) {
    final nextBubbleRect = bubbleRect ?? this.bubbleRect;
    return MessageLongPressDetails(
      message: message ?? this.message,
      bubbleRect: nextBubbleRect,
      isMe: isMe ?? this.isMe,
      visibleRect: visibleRect ?? nextBubbleRect,
    );
  }

  final ConversationMessage message;
  final Rect bubbleRect;
  final bool isMe;
  final Rect visibleRect;

  Rect get sourceRect => bubbleRect;
}

class MessageRow extends StatefulWidget {
  const MessageRow({
    super.key,
    required this.message,
    required this.chatMessageFontSize,
    this.isHighlighted = false,
    this.onLongPress,
    this.onReply,
    this.onTapReply,
    this.onOpenThread,
    this.onToggleReaction,
    this.showSenderName = true,
    this.showAvatar = true,
  });

  final ConversationMessage message;
  final double chatMessageFontSize;
  final bool isHighlighted;
  final ValueChanged<MessageLongPressDetails>? onLongPress;
  final VoidCallback? onReply;
  final VoidCallback? onTapReply;
  final VoidCallback? onOpenThread;
  final ValueChanged<String>? onToggleReaction;
  final bool showSenderName;
  final bool showAvatar;

  @override
  State<MessageRow> createState() => _MessageRowState();
}

class _MessageRowState extends State<MessageRow>
    with SingleTickerProviderStateMixin {
  static const double _replyThreshold = 60;
  static const double _rowHorizontalPadding =
      MessageBubblePresentation.rowHorizontalPadding / 2;
  static const Set<String> _replyableMessageTypes = <String>{
    'text',
    'audio',
    'sticker',
    'invite',
  };

  double _dragOffset = 0;
  bool _hasTriggeredReply = false;
  final GlobalKey _bubbleKey = GlobalKey();

  bool get _isMe {
    final currentUserId = ApiSession.currentUserId;
    return widget.message.sender.uid == currentUserId;
  }

  bool get _isDesktopPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        return true;
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  bool get _canReply =>
      widget.onReply != null &&
      !widget.message.isDeleted &&
      _replyableMessageTypes.contains(widget.message.messageType);

  void _handleLongPress() {
    final context = _bubbleKey.currentContext;
    if (widget.onLongPress == null || context == null) {
      return;
    }
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.attached) {
      return;
    }
    final origin = renderBox.localToGlobal(Offset.zero);
    widget.onLongPress!(
      MessageLongPressDetails(
        message: widget.message,
        bubbleRect: origin & renderBox.size,
        isMe: _isMe,
      ),
    );
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!_canReply) {
      return;
    }

    setState(() {
      _dragOffset = (_dragOffset + details.delta.dx).clamp(
        -_replyThreshold * 1.3,
        0,
      );
    });
    if (!_hasTriggeredReply && _dragOffset <= -_replyThreshold) {
      _hasTriggeredReply = true;
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!_canReply) {
      return;
    }

    if (_hasTriggeredReply) {
      widget.onReply?.call();
    }
    _hasTriggeredReply = false;
    setState(() => _dragOffset = 0);
  }

  Future<void> _openAttachment(AttachmentItem attachment) async {
    if (attachment.url.isEmpty) {
      return;
    }

    if (attachment.isImage) {
      if (!mounted) return;
      await context.push(AppRoutes.attachmentViewer, extra: attachment);
      return;
    }

    if (attachment.isVideo) {
      if (!mounted) return;
      await showVideoPlayerPopup(context, attachment);
      return;
    }

    await launchUrl(
      Uri.parse(attachment.url),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final presentation = MessageBubblePresentation.fromContext(
      context: context,
      message: widget.message,
      isMe: _isMe,
      chatMessageFontSize: widget.chatMessageFontSize,
    );
    final replyIconOpacity = _canReply
        ? (_dragOffset.abs() / _replyThreshold).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onLongPress: _isDesktopPlatform ? null : _handleLongPress,
      onSecondaryTapUp: _isDesktopPlatform ? (_) => _handleLongPress() : null,
      onHorizontalDragUpdate: _canReply ? _onHorizontalDragUpdate : null,
      onHorizontalDragEnd: _canReply ? _onHorizontalDragEnd : null,
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          if (_canReply)
            Positioned(
              right: 16,
              child: Opacity(
                opacity: replyIconOpacity,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: colors.chatReplyActionBackground,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.reply,
                    size: 22,
                    color: CupertinoColors.activeBlue,
                  ),
                ),
              ),
            ),
          AnimatedContainer(
            duration: _dragOffset == 0
                ? const Duration(milliseconds: 200)
                : Duration.zero,
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(_dragOffset, 0, 0),
            child: _buildMessageRow(context, presentation),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageRow(
    BuildContext context,
    MessageBubblePresentation presentation,
  ) {
    final bubble = MessageBubble(
      key: _bubbleKey,
      message: widget.message,
      presentation: presentation,
      chatMessageFontSize: widget.chatMessageFontSize,
      isMe: _isMe,
      showSenderName: widget.showSenderName,
      onTapReply: widget.onTapReply,
      onOpenThread: widget.onOpenThread,
      onOpenAttachment: _openAttachment,
      onToggleReaction: widget.onToggleReaction,
    );
    final avatar = _buildAvatar(context, presentation.senderName);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      decoration: BoxDecoration(
        color: widget.isHighlighted
            ? CupertinoColors.systemYellow.withAlpha(60)
            : const Color(0x00000000),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _rowHorizontalPadding,
          vertical: 4,
        ),
        child: Align(
          alignment: _isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: _isMe
                ? [
                    bubble,
                    if (widget.showAvatar) ...[
                      const SizedBox(
                        width: MessageBubblePresentation.avatarGap,
                      ),
                      avatar,
                    ] else
                      const SizedBox(
                        width: MessageBubblePresentation.avatarSlotWidth,
                      ),
                  ]
                : [
                    if (widget.showAvatar) ...[
                      avatar,
                      const SizedBox(
                        width: MessageBubblePresentation.avatarGap,
                      ),
                    ] else
                      const SizedBox(
                        width: MessageBubblePresentation.avatarSlotWidth,
                      ),
                    bubble,
                  ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, String senderName) {
    final avatarUrl = widget.message.sender.avatarUrl;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return MessageAvatar(
        avatarUrl: avatarUrl,
        fallbackBuilder: () => _buildFallbackAvatar(context, senderName),
      );
    }
    final initial = (senderName.isNotEmpty ? senderName[0] : '?').toUpperCase();
    return _buildFallbackAvatar(context, initial);
  }

  // Build fallback avatar from user's initial
  Widget _buildFallbackAvatar(BuildContext context, String initial) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: context.appColors.avatarBackground,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: appOnDarkTextStyle(
          context,
          fontSize: AppFontSizes.bodySmall,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
