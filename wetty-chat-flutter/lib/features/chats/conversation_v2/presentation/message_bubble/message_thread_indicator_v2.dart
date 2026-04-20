import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/features/chats/models/message_models.dart';
import 'package:flutter/cupertino.dart';

import 'message_bubble_presentation_v2.dart';

class MessageThreadIndicatorV2 extends StatelessWidget {
  const MessageThreadIndicatorV2({
    super.key,
    required this.threadInfo,
    required this.isMe,
    required this.presentation,
    this.onTap,
  });

  final ThreadInfo threadInfo;
  final bool isMe;
  final MessageBubblePresentationV2 presentation;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = isMe
        ? CupertinoColors.white.withAlpha(51)
        : CupertinoColors.black.withAlpha(20);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: borderColor, width: 1)),
        ),
        child: Opacity(
          opacity: 0.8,
          child: Row(
            mainAxisAlignment: isMe
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              Icon(
                CupertinoIcons.chat_bubble_2,
                size: 12,
                color: presentation.textColor,
              ),
              const SizedBox(width: 4),
              Text(
                '${threadInfo.replyCount} repl${threadInfo.replyCount == 1 ? 'y' : 'ies'}',
                style: appBubbleTextStyle(
                  context,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: presentation.textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
