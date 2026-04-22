import 'package:flutter/cupertino.dart';

import '../../../../app/theme/style_config.dart';

/// Wraps a message row with swipe-to-reply affordance and motion.
class ReplySwipeActionV2 extends StatefulWidget {
  const ReplySwipeActionV2({
    super.key,
    required this.child,
    this.enabled = true,
    this.onTriggered,
    this.threshold = 60,
  });

  final Widget child;
  final bool enabled;
  final VoidCallback? onTriggered;
  final double threshold;

  @override
  State<ReplySwipeActionV2> createState() => _ReplySwipeActionV2State();
}

class _ReplySwipeActionV2State extends State<ReplySwipeActionV2> {
  double _dragOffset = 0;

  double get _minimumOffset => -widget.threshold * 1.3;

  @override
  void didUpdateWidget(covariant ReplySwipeActionV2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled || oldWidget.child.key != widget.child.key) {
      _dragOffset = 0;
    }
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled) {
      return;
    }

    setState(() {
      _dragOffset = (_dragOffset + details.delta.dx).clamp(_minimumOffset, 0);
    });
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    if (!widget.enabled) {
      return;
    }

    final shouldTrigger = _dragOffset <= -widget.threshold;
    if (shouldTrigger) {
      widget.onTriggered?.call();
    }

    setState(() {
      _dragOffset = 0;
    });
  }

  void _handleHorizontalDragCancel() {
    if (_dragOffset == 0) {
      return;
    }
    setState(() {
      _dragOffset = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final replyIconOpacity = widget.enabled
        ? (_dragOffset.abs() / widget.threshold).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onHorizontalDragUpdate: widget.enabled
          ? _handleHorizontalDragUpdate
          : null,
      onHorizontalDragEnd: widget.enabled ? _handleHorizontalDragEnd : null,
      onHorizontalDragCancel: widget.enabled
          ? _handleHorizontalDragCancel
          : null,
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          if (widget.enabled)
            Positioned(
              right: 16,
              child: Opacity(
                opacity: replyIconOpacity,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: colors.chatReplyActionBackground,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.reply,
                    size: 22,
                    color: CupertinoColors.activeBlue,
                  ),
                ),
              ),
            ),
          AnimatedContainer(
            duration: _dragOffset == 0
                ? const Duration(milliseconds: 200)
                : Duration.zero,
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(_dragOffset, 0, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
