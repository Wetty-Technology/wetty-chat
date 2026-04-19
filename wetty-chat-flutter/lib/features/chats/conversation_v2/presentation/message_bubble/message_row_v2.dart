import 'package:chahua/features/chats/conversation_v2/domain/conversation_message_v2.dart';
import 'package:chahua/features/chats/conversation_v2/presentation/message_bubble/message_bubble_v2.dart';
import 'package:flutter/cupertino.dart';

/// This is the abstraction for handling a message in the timeline. It includes
/// the message bubble and avatar etc, also handles alignment.
class MessageRowV2 extends StatelessWidget {
  const MessageRowV2({
    super.key,
    required this.message,
    this.isHighlighted = false,
  });

  static const double _bottomSpacing = 12;

  final ConversationMessageV2 message;
  final bool isHighlighted;

  bool get _isMe => message.sender.uid == 1;

  @override
  Widget build(BuildContext context) {
    // TODO: Handle Avatar
    // TODO: Handle grouping: i.e. hiding avatar / username
    return Padding(
      padding: const EdgeInsets.only(bottom: _bottomSpacing),
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
          child: Align(
            alignment: _isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: MessageBubbleV2(message: message, isMe: _isMe),
          ),
        ),
      ),
    );
  }
}
