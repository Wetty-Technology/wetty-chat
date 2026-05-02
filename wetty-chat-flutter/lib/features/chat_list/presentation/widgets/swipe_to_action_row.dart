import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_swipe_action_cell/flutter_swipe_action_cell.dart';
import 'package:chahua/app/theme/style_config.dart';

/// iOS-style swipe-to-action row for chat list items.
/// Partial swipe reveals the action button; full swipe triggers it automatically.
class SwipeToActionRow extends StatelessWidget {
  const SwipeToActionRow({
    super.key,
    required this.child,
    required this.icon,
    required this.label,
    required this.onAction,
    this.actionColor,
  });

  final Widget child;
  final IconData icon;
  final String label;
  final FutureOr<void> Function() onAction;
  final Color? actionColor;

  @override
  Widget build(BuildContext context) {
    final color = actionColor ?? CupertinoColors.activeBlue;

    return SwipeActionCell(
      key: key!,
      backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
      fullSwipeFactor: 0.6,
      leadingActions: [
        SwipeAction(
          performsFirstActionWithFullSwipe: true,
          onTap: (handler) async {
            await onAction();
            await handler(false);
          },
          color: color,
          icon: Icon(icon, color: CupertinoColors.white),
          title: label,
          style: appCaptionTextStyle(context, color: CupertinoColors.white),
        ),
      ],
      child: child,
    );
  }
}
