import 'package:flutter/cupertino.dart';
import 'package:flutter_swipe_action_cell/flutter_swipe_action_cell.dart';

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
  final VoidCallback onAction;
  final Color? actionColor;

  @override
  Widget build(BuildContext context) {
    final color = actionColor ?? CupertinoColors.activeBlue;

    return SwipeActionCell(
      key: key!,
      backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
      leadingActions: [
        SwipeAction(
          performsFirstActionWithFullSwipe: true,
          onTap: (handler) async {
            onAction();
            await handler(false);
          },
          color: color,
          icon: Icon(icon, color: CupertinoColors.white),
          title: label,
          style: const TextStyle(color: CupertinoColors.white, fontSize: 12),
        ),
      ],
      child: child,
    );
  }
}
