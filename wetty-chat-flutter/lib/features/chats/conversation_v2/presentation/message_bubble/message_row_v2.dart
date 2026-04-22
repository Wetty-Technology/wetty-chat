import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/core/network/api_config.dart';
import 'package:chahua/shared/presentation/app_avatar.dart';
import 'package:chahua/features/chats/conversation_v2/domain/conversation_message_v2.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';

import '../message_long_press_details_v2.dart';
import '../reply_swipe_action_v2.dart';
import 'message_bubble_v2.dart';
import 'message_bubble_presentation_v2.dart';

class MessageRowV2 extends StatefulWidget {
  const MessageRowV2({
    super.key,
    required this.message,
    required this.chatMessageFontSize,
    this.isHighlighted = false,
    this.onLongPress,
    this.onReply,
    this.onToggleReaction,
    this.onTapReply,
    this.onOpenThread,
    this.showSenderName = true,
    this.showAvatar = true,
  });

  static const double _bottomSpacing = 12;
  static const double _rowHorizontalPadding =
      MessageBubblePresentationV2.rowHorizontalPadding / 2;
  static const double _avatarLaneWidth =
      MessageBubblePresentationV2.avatarSlotWidth +
      MessageBubblePresentationV2.avatarGap;

  final ConversationMessageV2 message;
  final double chatMessageFontSize;
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
  bool get _isSystem => widget.message.content is SystemMessageContent;
  bool get _canReply =>
      widget.onReply != null &&
      !widget.message.isDeleted &&
      switch (widget.message.content) {
        TextMessageContent() ||
        AudioMessageContent() ||
        StickerMessageContent() ||
        InviteMessageContent() => true,
        SystemMessageContent() ||
        FileMessageContent() => false,
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
    if (_isSystem) {
      return _SystemMessageRowV2(message: widget.message);
    }

    final avatar = widget.showAvatar
        ? Padding(
            padding: EdgeInsets.only(
              left: MessageBubblePresentationV2.avatarGap,
            ),
            child: AppAvatar(
              imageUrl: widget.message.sender.avatarUrl,
              size: MessageBubblePresentationV2.avatarSlotWidth,
              name: widget.message.sender.name,
            ),
          )
        : const SizedBox.shrink();

    final bubble = KeyedSubtree(
      key: _bubbleKey,
      child: MessageBubbleV2(
        message: widget.message,
        isMe: _isMe,
        chatMessageFontSize: widget.chatMessageFontSize,
        showSenderName: widget.showSenderName,
        onToggleReaction: widget.onToggleReaction,
        onTapReply: widget.onTapReply,
        onOpenThread: widget.onOpenThread,
      ),
    );

    return GestureDetector(
      onLongPress: _isDesktopPlatform ? null : _handleLongPress,
      onSecondaryTapUp: _isDesktopPlatform ? (_) => _handleLongPress() : null,
      child: Padding(
        padding: const EdgeInsets.only(bottom: MessageRowV2._bottomSpacing),
        child: ReplySwipeActionV2(
          key: ValueKey(widget.message.stableKey),
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
            child: Padding(
              padding: widget.isHighlighted
                  ? const EdgeInsets.all(2)
                  : EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: MessageRowV2._rowHorizontalPadding,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: _isMe
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  children: _isMe
                      ? <Widget>[
                          Flexible(child: bubble),
                          const SizedBox(width: MessageRowV2._avatarLaneWidth),
                        ]
                      : <Widget>[
                          SizedBox(
                            width: MessageRowV2._avatarLaneWidth,
                            child: Align(
                              alignment: Alignment.bottomLeft,
                              child: avatar,
                            ),
                          ),
                          Flexible(child: bubble),
                        ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SystemMessageRowV2 extends StatelessWidget {
  const _SystemMessageRowV2({required this.message});

  static const double _horizontalPadding = 16;
  static const double _verticalPadding = 8;
  static const double _maxContentWidth = 520;
  static const double _lineHeight = 1.45;

  final ConversationMessageV2 message;

  @override
  Widget build(BuildContext context) {
    final senderName = message.sender.name?.trim();
    final hasSenderName = senderName != null && senderName.isNotEmpty;
    final messageText = message.isDeleted
        ? '[Deleted]'
        : switch (message.content) {
            SystemMessageContent(:final text) => text,
            _ => '',
          };

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _horizontalPadding,
        vertical: _verticalPadding,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxContentWidth),
          child: RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: appSecondaryTextStyle(
                context,
                fontSize: AppFontSizes.bodySmall,
                height: _lineHeight,
              ),
              children: [
                if (hasSenderName)
                  TextSpan(
                    text: senderName,
                    style: appSecondaryTextStyle(
                      context,
                      fontSize: AppFontSizes.bodySmall,
                      height: _lineHeight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (hasSenderName) const TextSpan(text: ' '),
                TextSpan(text: messageText),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
