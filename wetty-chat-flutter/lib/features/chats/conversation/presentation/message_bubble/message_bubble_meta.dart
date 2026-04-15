import 'package:flutter/cupertino.dart';

import '../../../../../app/theme/style_config.dart';
import '../../domain/conversation_message.dart';
import 'message_bubble_presentation.dart';

class MessageBubbleMeta extends StatelessWidget {
  const MessageBubbleMeta({
    super.key,
    required this.message,
    required this.presentation,
    required this.isMe,
    this.fontWeight = FontWeight.w400,
  });

  final ConversationMessage message;
  final MessageBubblePresentation presentation;
  final bool isMe;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    final showDeliveryStatus = isMe && !message.isFailed;
    final deliveryIndicator = switch (message.deliveryState) {
      ConversationDeliveryState.sending => Icon(
        CupertinoIcons.checkmark_alt_circle,
        size: MessageBubblePresentation.statusIconSize,
        color: presentation.metaColor,
      ),
      ConversationDeliveryState.sent => Icon(
        CupertinoIcons.checkmark_alt_circle,
        size: MessageBubblePresentation.statusIconSize,
        color: presentation.metaColor,
      ),
      ConversationDeliveryState.confirmed => Icon(
        CupertinoIcons.checkmark_alt_circle_fill,
        size: MessageBubblePresentation.statusIconSize,
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
              'edited', // TODO: localize
              style: appBubbleTextStyle(
                context,
                color: presentation.metaColor,
                fontSize: AppFontSizes.bubbleMeta,
                fontWeight: fontWeight,
              ),
            ),
          ),
        Text(
          presentation.timeStr,
          style: appBubbleTextStyle(
            context,
            color: presentation.metaColor,
            fontSize: AppFontSizes.bubbleMeta,
            fontWeight: fontWeight,
          ),
        ),
        if (showDeliveryStatus && deliveryIndicator != null) ...[
          const SizedBox(width: MessageBubblePresentation.statusIconGap),
          deliveryIndicator,
        ],
      ],
    );
  }
}
