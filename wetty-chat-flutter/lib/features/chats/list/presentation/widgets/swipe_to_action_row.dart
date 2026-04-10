import 'package:flutter/cupertino.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

/// iOS-style swipe-to-reveal-action row for chat list items.
/// Swipe left-to-right to reveal an action from the left edge.
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
    return Slidable(
      key: key,
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (_) => onAction(),
            backgroundColor: actionColor ?? CupertinoColors.activeBlue,
            foregroundColor: CupertinoColors.white,
            icon: icon,
            label: label,
          ),
        ],
      ),
      child: child,
    );
  }
}
