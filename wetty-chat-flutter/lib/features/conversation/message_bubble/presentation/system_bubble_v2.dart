import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/features/shared/model/message/message.dart';
import 'package:flutter/cupertino.dart';

class SystemBubbleV2 extends StatelessWidget {
  const SystemBubbleV2({super.key, required this.message});

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
