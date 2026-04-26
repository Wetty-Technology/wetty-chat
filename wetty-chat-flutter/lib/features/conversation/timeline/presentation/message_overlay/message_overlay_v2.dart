import 'dart:ui';

import 'package:chahua/features/conversation/timeline/model/message_long_press_details_v2.dart';
import 'package:chahua/features/shared/model/message/message.dart';
import 'package:flutter/cupertino.dart';

import 'message_overlay_action_v2.dart';
import 'message_overlay_bubble_v2.dart';
import 'message_overlay_controls_v2.dart';
import 'message_overlay_layout_v2.dart';

class MessageOverlayV2 extends StatelessWidget {
  const MessageOverlayV2({
    super.key,
    required this.details,
    required this.visible,
    required this.actions,
    required this.quickReactionEmojis,
    required this.onDismiss,
    required this.onToggleReaction,
  });

  final MessageLongPressDetailsV2 details;
  final bool visible;
  final List<MessageOverlayActionV2> actions;
  final List<String> quickReactionEmojis;
  final VoidCallback onDismiss;
  final ValueChanged<String> onToggleReaction;

  bool get _showReactionBar =>
      !details.message.isDeleted &&
      details.message.content is! StickerMessageContent;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = MessageOverlayLayoutV2.calculate(
          viewportSize: constraints.biggest,
          mediaPadding: MediaQuery.paddingOf(context),
          sourceBubbleRect: details.bubbleRect,
          isMe: details.isMe,
          actionCount: actions.length,
          showReactionBar: _showReactionBar,
        );

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: _OverlayBackdrop(visible: visible, onDismiss: onDismiss),
            ),
            Positioned.fromRect(
              rect: layout.bubbleRect,
              child: _AnimatedOverlayChild(
                visible: visible,
                duration: const Duration(milliseconds: 160),
                alignment: details.isMe
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: ClipRect(
                  child: OverflowBox(
                    alignment: details.isMe
                        ? Alignment.topRight
                        : Alignment.topLeft,
                    minWidth: layout.bubbleRect.width,
                    maxWidth: layout.bubbleRect.width,
                    maxHeight: details.bubbleRect.height,
                    child: MessageOverlayBubbleV2(details: details),
                  ),
                ),
              ),
            ),
            if (_showReactionBar)
              if (layout.reactionBarRect case final rect?)
                Positioned.fromRect(
                  rect: rect,
                  child: _AnimatedOverlayChild(
                    visible: visible,
                    duration: const Duration(milliseconds: 160),
                    alignment: _alignmentFor(
                      details.isMe,
                      layout.reactionBarSide,
                    ),
                    child: MessageOverlayReactionBarV2(
                      emojis: quickReactionEmojis,
                      onToggleReaction: onToggleReaction,
                    ),
                  ),
                ),
            Positioned.fromRect(
              rect: layout.actionPanelRect,
              child: _AnimatedOverlayChild(
                visible: visible,
                duration: const Duration(milliseconds: 180),
                alignment: _alignmentFor(details.isMe, layout.actionPanelSide),
                child: MessageOverlayActionPanelV2(actions: actions),
              ),
            ),
          ],
        );
      },
    );
  }

  Alignment _alignmentFor(bool isMe, MessageOverlaySideV2? side) {
    return switch ((isMe, side)) {
      (true, MessageOverlaySideV2.above) => Alignment.bottomRight,
      (true, MessageOverlaySideV2.below) => Alignment.topRight,
      (false, MessageOverlaySideV2.above) => Alignment.bottomLeft,
      (false, MessageOverlaySideV2.below) => Alignment.topLeft,
      (true, null) => Alignment.centerRight,
      (false, null) => Alignment.centerLeft,
    };
  }
}

class _OverlayBackdrop extends StatelessWidget {
  const _OverlayBackdrop({required this.visible, required this.onDismiss});

  final bool visible;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: visible ? 1 : 0),
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) =>
            Opacity(opacity: value, child: child),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onDismiss,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: ColoredBox(color: CupertinoColors.black.withAlpha(56)),
          ),
        ),
      ),
    );
  }
}

class _AnimatedOverlayChild extends StatelessWidget {
  const _AnimatedOverlayChild({
    required this.visible,
    required this.duration,
    required this.alignment,
    required this.child,
  });

  final bool visible;
  final Duration duration;
  final Alignment alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: visible ? 1 : 0),
        duration: duration,
        curve: Curves.easeOutCubic,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.scale(
            scale: 0.96 + (0.04 * value),
            alignment: alignment,
            child: child,
          ),
        ),
        child: child,
      ),
    );
  }
}
