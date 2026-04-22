import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/core/network/api_config.dart';
import 'package:chahua/shared/presentation/app_avatar.dart';
import 'package:chahua/features/chats/conversation_v2/domain/conversation_message_v2.dart';
import 'package:flutter/cupertino.dart';

import '../reply_swipe_action_v2.dart';
import 'message_bubble_v2.dart';
import 'message_bubble_presentation_v2.dart';

class MessageRowV2 extends StatelessWidget {
  const MessageRowV2({
    super.key,
    required this.message,
    required this.chatMessageFontSize,
    this.isHighlighted = false,
    this.onReply,
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
  final VoidCallback? onReply;
  final VoidCallback? onTapReply;
  final VoidCallback? onOpenThread;
  final bool showSenderName;
  final bool showAvatar;

  bool get _isMe => message.sender.uid == ApiSession.currentUserId;
  bool get _isSystem => message.content is SystemMessageContent;
  bool get _canReply =>
      onReply != null &&
      !message.isDeleted &&
      switch (message.content) {
        TextMessageContent() ||
        AudioMessageContent() ||
        StickerMessageContent() ||
        InviteMessageContent() => true,
        SystemMessageContent() ||
        FileMessageContent() => false,
      };

  @override
  Widget build(BuildContext context) {
    if (_isSystem) {
      return _SystemMessageRowV2(message: message);
    }

    final avatar = showAvatar
        ? Padding(
            padding: EdgeInsets.only(
              left: MessageBubblePresentationV2.avatarGap,
            ),
            child: AppAvatar(
              imageUrl: message.sender.avatarUrl,
              size: MessageBubblePresentationV2.avatarSlotWidth,
              name: message.sender.name,
            ),
          )
        : const SizedBox.shrink();

    final bubble = MessageBubbleV2(
      message: message,
      isMe: _isMe,
      chatMessageFontSize: chatMessageFontSize,
      showSenderName: showSenderName,
      onTapReply: onTapReply,
      onOpenThread: onOpenThread,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: _bottomSpacing),
      child: ReplySwipeActionV2(
        key: ValueKey(message.stableKey),
        enabled: _canReply,
        onTriggered: onReply,
        child: DecoratedBox(
          decoration: isHighlighted
              ? BoxDecoration(
                  border: Border.all(
                    color: CupertinoColors.activeBlue,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(14),
                )
              : const BoxDecoration(),
          child: Padding(
            padding: isHighlighted ? const EdgeInsets.all(2) : EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _rowHorizontalPadding,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: _isMe
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                children: _isMe
                    ? <Widget>[
                        Flexible(child: bubble),
                        const SizedBox(width: _avatarLaneWidth),
                      ]
                    : <Widget>[
                        SizedBox(
                          width: _avatarLaneWidth,
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
