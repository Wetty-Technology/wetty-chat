import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/features/shared/model/message/message.dart';
import 'package:flutter/cupertino.dart';

import '../../domain/bubble_theme_v2.dart';

class ThreadIndicator extends StatelessWidget {
  const ThreadIndicator({super.key, required this.threadInfo, this.onTap});

  final ThreadInfo threadInfo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = BubbleThemeV2.of(context);
    final borderColor = theme.isMe
        ? CupertinoColors.white.withAlpha(51)
        : CupertinoColors.black.withAlpha(20);
    final effectiveOnTap = theme.isInteractive ? onTap : null;

    final indicator = Container(
      padding: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: borderColor, width: 1)),
      ),
      child: Opacity(
        opacity: 0.8,
        child: Row(
          mainAxisAlignment: theme.isMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            Icon(
              CupertinoIcons.chat_bubble_2,
              size: 12,
              color: theme.textColor,
            ),
            const SizedBox(width: 4),
            Text(
              '${threadInfo.replyCount} repl${threadInfo.replyCount == 1 ? 'y' : 'ies'}',
              style: appBubbleTextStyle(
                context,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: theme.textColor,
              ),
            ),
          ],
        ),
      ),
    );

    if (effectiveOnTap == null) {
      return indicator;
    }
    return GestureDetector(onTap: effectiveOnTap, child: indicator);
  }
}
