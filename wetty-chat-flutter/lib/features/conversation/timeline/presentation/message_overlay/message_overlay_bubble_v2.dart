import 'package:chahua/features/conversation/message_bubble/presentation/message_item.dart';
import 'package:chahua/features/conversation/timeline/presentation/message_long_press_details_v2.dart';
import 'package:flutter/cupertino.dart';

class MessageOverlayBubbleV2 extends StatelessWidget {
  const MessageOverlayBubbleV2({super.key, required this.details});

  final MessageLongPressDetailsV2 details;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: details.isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: MessageItem(
          message: details.message,
          isMe: details.isMe,
          isInteractive: false,
          showSenderName: details.sourceShowsSenderName,
        ),
      ),
    );
  }
}
