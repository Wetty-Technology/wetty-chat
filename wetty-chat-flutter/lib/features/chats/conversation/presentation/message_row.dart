import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:go_router/go_router.dart';

import '../../../../app/routing/route_names.dart';
import '../../../../app/theme/style_config.dart';
import '../../../../core/network/api_config.dart';
import '../../../../shared/presentation/app_avatar.dart';
import '../../models/message_models.dart';
import '../domain/conversation_message.dart';
import '../../conversation_v2/presentation/attachment_viewer_request.dart';
import 'message_bubble/message_bubble.dart';
import 'message_bubble/message_bubble_presentation.dart';
import 'message_bubble/message_render_spec.dart';
import 'message_bubble/voice_message_bubble.dart';
import 'reply_swipe_action.dart';

class MessageLongPressDetails {
  const MessageLongPressDetails({
    required this.message,
    required this.bubbleRect,
    required this.isMe,
    required this.sourceShowsSenderName,
    Rect? visibleRect,
  }) : visibleRect = visibleRect ?? bubbleRect;

  MessageLongPressDetails copyWith({
    ConversationMessage? message,
    Rect? bubbleRect,
    bool? isMe,
    bool? sourceShowsSenderName,
    Rect? visibleRect,
  }) {
    final nextBubbleRect = bubbleRect ?? this.bubbleRect;
    return MessageLongPressDetails(
      message: message ?? this.message,
      bubbleRect: nextBubbleRect,
      isMe: isMe ?? this.isMe,
      sourceShowsSenderName:
          sourceShowsSenderName ?? this.sourceShowsSenderName,
      visibleRect: visibleRect ?? nextBubbleRect,
    );
  }

  final ConversationMessage message;
  final Rect bubbleRect;
  final bool isMe;
  final bool sourceShowsSenderName;
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
    this.onTapSticker,
    this.onTapReply,
    this.onOpenThread,
    this.onToggleReaction,
    this.onTapMention,
    this.onRetryFailed,
    this.showSenderName = true,
    this.showAvatar = true,
  });

  final ConversationMessage message;
  final double chatMessageFontSize;
  final bool isHighlighted;
  final ValueChanged<MessageLongPressDetails>? onLongPress;
  final VoidCallback? onReply;
  final VoidCallback? onTapSticker;
  final VoidCallback? onTapReply;
  final VoidCallback? onOpenThread;
  final ValueChanged<String>? onToggleReaction;
  final void Function(int uid, MentionInfo? mention)? onTapMention;
  final VoidCallback? onRetryFailed;
  final bool showSenderName;
  final bool showAvatar;

  @override
  State<MessageRow> createState() => _MessageRowState();
}

class _MessageRowState extends State<MessageRow> {
  static const double _rowHorizontalPadding =
      MessageBubblePresentation.rowHorizontalPadding / 2;
  static const double _avatarLaneWidth =
      MessageBubblePresentation.avatarSlotWidth +
      MessageBubblePresentation.avatarGap;
  static const Set<String> _replyableMessageTypes = <String>{
    'text',
    'audio',
    'sticker',
    'invite',
  };

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

  bool get _isPureAudioMessage =>
      widget.message.messageType == 'audio' &&
      widget.message.attachments.length == 1 &&
      widget.message.attachments.first.isAudio;

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
        sourceShowsSenderName: widget.showSenderName,
      ),
    );
  }

  Future<void> _openAttachment(MessageAttachmentOpenRequest request) async {
    final attachment = request.attachment;
    if (attachment.url.isEmpty) {
      return;
    }

    if (attachment.isImage || attachment.isVideo) {
      final viewerRequest = request.viewerRequest;
      if (viewerRequest == null) {
        return;
      }
      if (!mounted) return;
      await context.push(AppRoutes.attachmentViewer, extra: viewerRequest);
      return;
    }

    await launchUrl(
      Uri.parse(attachment.url),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final presentation = MessageBubblePresentation.fromContext(
      context: context,
      message: widget.message,
      isMe: _isMe,
      chatMessageFontSize: widget.chatMessageFontSize,
    );

    return GestureDetector(
      onLongPress: _isDesktopPlatform ? null : _handleLongPress,
      onSecondaryTapUp: _isDesktopPlatform ? (_) => _handleLongPress() : null,
      child: ReplySwipeAction(
        key: ValueKey(widget.message.stableKey),
        enabled: _canReply,
        onTriggered: widget.onReply,
        child: _buildMessageRow(context, presentation),
      ),
    );
  }

  Widget _buildMessageRow(
    BuildContext context,
    MessageBubblePresentation presentation,
  ) {
    final avatarColumnWidth = _avatarLaneWidth;
    final failedRetryButton =
        _isMe && widget.message.isFailed && widget.onRetryFailed != null
        ? Padding(
            padding: const EdgeInsets.only(right: 6, bottom: 4),
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(24, 24),
              onPressed: widget.onRetryFailed,
              child: Icon(
                CupertinoIcons.arrow_clockwise_circle_fill,
                size: 22,
                color: CupertinoColors.systemRed.resolveFrom(context),
              ),
            ),
          )
        : null;
    final renderSpec = MessageRenderSpec.timeline(
      message: widget.message,
      showSenderName: widget.showSenderName,
      showThreadIndicator: widget.onOpenThread != null,
      isInteractive: true,
    );
    final bubble = _isPureAudioMessage
        ? KeyedSubtree(
            key: _bubbleKey,
            child: VoiceMessageBubble(
              attachment: widget.message.attachments.first,
              isMe: _isMe,
              renderSpec: renderSpec,
              message: widget.message,
              presentation: presentation,
            ),
          )
        : MessageBubble(
            key: _bubbleKey,
            message: widget.message,
            presentation: presentation,
            chatMessageFontSize: widget.chatMessageFontSize,
            isMe: _isMe,
            renderSpec: renderSpec,
            currentUserId: ApiSession.currentUserId,
            onTapSticker: widget.onTapSticker,
            onTapReply: widget.onTapReply,
            onOpenThread: widget.onOpenThread,
            onOpenAttachment: _openAttachment,
            onToggleReaction: widget.onToggleReaction,
            onTapMention: widget.onTapMention,
          );
    final avatar = _buildAvatar(context, presentation.senderName);
    final trailingAvatarColumn = SizedBox(
      width: avatarColumnWidth,
      child: Row(
        children: [
          const SizedBox(width: MessageBubblePresentation.avatarGap),
          if (widget.showAvatar) avatar,
        ],
      ),
    );
    final leadingAvatarColumn = SizedBox(
      width: avatarColumnWidth,
      child: Row(
        children: [
          if (widget.showAvatar) avatar,
          const SizedBox(width: MessageBubblePresentation.avatarGap),
        ],
      ),
    );

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
                ? [?failedRetryButton, bubble, trailingAvatarColumn]
                : [leadingAvatarColumn, bubble],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, String senderName) {
    return AppAvatar(
      name: senderName,
      imageUrl: widget.message.sender.avatarUrl,
      size: 36,
      memCacheWidth: 96,
      fallbackTextStyle: appOnDarkTextStyle(
        context,
        fontSize: AppFontSizes.bodySmall,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
