import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/features/chats/conversation_v2/domain/conversation_message_v2.dart';
import 'package:flutter/cupertino.dart';

import 'message_bubble_presentation_v2.dart';

class MessageBubbleMetaV2 extends StatelessWidget {
  const MessageBubbleMetaV2({
    super.key,
    required this.message,
    required this.presentation,
    required this.isMe,
    this.fontWeight = FontWeight.w400,
  });

  final ConversationMessageV2 message;
  final MessageBubblePresentationV2 presentation;
  final bool isMe;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    final showDeliveryStatus =
        isMe && message.deliveryState != ConversationDeliveryState.failed;
    final deliveryIndicator = switch (message.deliveryState) {
      ConversationDeliveryState.sending || ConversationDeliveryState.sent =>
        Icon(
        CupertinoIcons.checkmark_alt_circle,
        size: MessageBubblePresentationV2.statusIconSize,
        color: presentation.metaColor,
      ),
      ConversationDeliveryState.confirmed => Icon(
        CupertinoIcons.checkmark_alt_circle_fill,
        size: MessageBubblePresentationV2.statusIconSize,
        color: presentation.metaColor,
      ),
      _ => null,
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (message.isEdited)
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Text(
              'edited',
              style: appBubbleTextStyle(
                context,
                color: presentation.metaColor,
                fontSize: AppFontSizes.bubbleMeta,
                fontWeight: fontWeight,
              ),
            ),
          ),
        Text(
          presentation.timeText,
          style: appBubbleTextStyle(
            context,
            color: presentation.metaColor,
            fontSize: AppFontSizes.bubbleMeta,
            fontWeight: fontWeight,
          ),
        ),
        if (showDeliveryStatus && deliveryIndicator != null) ...[
          const SizedBox(width: MessageBubblePresentationV2.statusIconGap),
          deliveryIndicator,
        ],
      ],
    );
  }
}
