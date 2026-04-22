import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/features/conversation/shared/domain/conversation_message_v2.dart';
import 'package:flutter/cupertino.dart';

import '../bubble_theme_v2.dart';

class MetaFooter extends StatelessWidget {
  const MetaFooter({
    super.key,
    required this.message,
    required this.theme,
    required this.isMe,
    this.fontWeight = FontWeight.w400,
  });

  final ConversationMessageV2 message;
  final BubbleThemeV2 theme;
  final bool isMe;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    final showDeliveryStatus =
        isMe && message.deliveryState != ConversationDeliveryState.failed;
    final deliveryIndicator = switch (message.deliveryState) {
      ConversationDeliveryState.sending ||
      ConversationDeliveryState.sent => Icon(
        CupertinoIcons.checkmark_alt_circle,
        size: BubbleThemeV2.statusIconSize,
        color: theme.metaColor,
      ),
      ConversationDeliveryState.confirmed => Icon(
        CupertinoIcons.checkmark_alt_circle_fill,
        size: BubbleThemeV2.statusIconSize,
        color: theme.metaColor,
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
                color: theme.metaColor,
                fontSize: AppFontSizes.bubbleMeta,
                fontWeight: fontWeight,
              ),
            ),
          ),
        Text(
          theme.timeText,
          style: appBubbleTextStyle(
            context,
            color: theme.metaColor,
            fontSize: AppFontSizes.bubbleMeta,
            fontWeight: fontWeight,
          ),
        ),
        if (showDeliveryStatus && deliveryIndicator != null) ...[
          const SizedBox(width: BubbleThemeV2.statusIconGap),
          deliveryIndicator,
        ],
      ],
    );
  }
}
