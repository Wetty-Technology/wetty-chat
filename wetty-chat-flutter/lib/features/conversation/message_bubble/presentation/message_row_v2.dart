import 'package:chahua/core/network/api_config.dart';
import 'package:chahua/shared/presentation/app_avatar.dart';
import 'package:chahua/features/conversation/shared/domain/conversation_message_v2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';

import '../../timeline/presentation/message_long_press_details_v2.dart';
import '../../timeline/presentation/reply_swipe_action_v2.dart';
import 'message_item.dart';

const double _bottomSpacing = 12;
const double _avatarSlotWidth = 36;
const double _avatarGap = 8;

/// Private bubble layout alignment
enum _BubbleLayout { centered, aligned }

class MessageRowV2 extends StatefulWidget {
  const MessageRowV2({
    super.key,
    required this.message,
    this.isHighlighted = false,
    this.onLongPress,
    this.onReply,
    this.onToggleReaction,
    this.onTapReply,
    this.onOpenThread,
    this.showSenderName = true,
    this.showAvatar = true,
  });

  final ConversationMessageV2 message;
  final bool isHighlighted;
  final ValueChanged<MessageLongPressDetailsV2>? onLongPress;
  final VoidCallback? onReply;
  final ValueChanged<String>? onToggleReaction;
  final VoidCallback? onTapReply;
  final VoidCallback? onOpenThread;
  final bool showSenderName;
  final bool showAvatar;

  @override
  State<MessageRowV2> createState() => _MessageRowV2State();
}

class _MessageRowV2State extends State<MessageRowV2> {
  final GlobalKey _bubbleKey = GlobalKey();

  bool get _isMe => widget.message.sender.uid == ApiSession.currentUserId;
  bool get _canReply =>
      widget.onReply != null &&
      !widget.message.isDeleted &&
      switch (widget.message.content) {
        TextMessageContent() ||
        AudioMessageContent() ||
        StickerMessageContent() ||
        InviteMessageContent() => true,
        SystemMessageContent() || FileMessageContent() => false,
      };
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

  _BubbleLayout _getBubbleLayout() {
    return switch (widget.message.content) {
      SystemMessageContent() => _BubbleLayout.centered,
      _ => _BubbleLayout.aligned,
    };
  }

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
      MessageLongPressDetailsV2(
        message: widget.message,
        bubbleRect: origin & renderBox.size,
        isMe: _isMe,
        sourceShowsSenderName: widget.showSenderName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = MessageItem(
      key: _bubbleKey,
      message: widget.message,
      isMe: _isMe,
      isInteractive: true,
      showSenderName: widget.showSenderName,
      onToggleReaction: widget.onToggleReaction,
      onTapReply: widget.onTapReply,
      onOpenThread: widget.onOpenThread,
    );

    // NOTE: Early return here!!!
    if (_getBubbleLayout() == _BubbleLayout.centered) {
      return item;
    }

    final avatar = Padding(
      padding: const EdgeInsets.symmetric(horizontal: _avatarGap),
      child: widget.showAvatar
          ? AppAvatar(
              imageUrl: widget.message.sender.avatarUrl,
              size: _avatarSlotWidth,
              name: widget.message.sender.name,
            )
          : const SizedBox.square(dimension: _avatarSlotWidth),
    );

    return GestureDetector(
      onLongPress: _isDesktopPlatform ? null : _handleLongPress,
      onSecondaryTapUp: _isDesktopPlatform ? (_) => _handleLongPress() : null,
      child: Padding(
        padding: const EdgeInsets.only(bottom: _bottomSpacing),
        child: ReplySwipeActionV2(
          enabled: _canReply,
          onTriggered: widget.onReply,
          child: DecoratedBox(
            decoration: widget.isHighlighted
                ? BoxDecoration(
                    border: Border.all(
                      color: CupertinoColors.activeBlue,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  )
                : const BoxDecoration(),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment
                  .end, // Important for tall message to align avatar at bottom
              textDirection: _isMe ? TextDirection.rtl : TextDirection.ltr,
              children: [
                avatar,
                Flexible(child: item),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
