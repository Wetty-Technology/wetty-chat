import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';

import '../../../../app/theme/style_config.dart';
import 'message_bubble/message_bubble.dart';
import 'message_bubble/message_bubble_presentation.dart';
import 'message_row.dart';

class MessageOverlayAction {
  const MessageOverlayAction({
    required this.label,
    required this.onPressed,
    this.icon,
    this.isDestructive = false,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
  final bool isDestructive;
}

class MessageOverlay extends StatelessWidget {
  const MessageOverlay({
    super.key,
    required this.details,
    required this.visible,
    required this.chatMessageFontSize,
    required this.actions,
    required this.quickReactionEmojis,
    required this.onDismiss,
    required this.onToggleReaction,
  });

  static const double _screenPadding = 16;
  static const double _clusterGap = 10;
  static const double _reactionBarHeight = 52;
  static const double _estimatedBubbleHeight = 132;
  static const double _actionRowHeight = 52;

  final MessageLongPressDetails details;
  final bool visible;
  final double chatMessageFontSize;
  final List<MessageOverlayAction> actions;
  final List<String> quickReactionEmojis;
  final VoidCallback onDismiss;
  final ValueChanged<String> onToggleReaction;

  bool get _showReactionBar => details.message.messageType != 'sticker';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final colors = context.appColors;
        final mediaQuery = MediaQuery.of(context);
        final viewportWidth = constraints.maxWidth;
        final viewportHeight = constraints.maxHeight;
        final safeTop = mediaQuery.padding.top + _screenPadding;
        final safeBottom = mediaQuery.padding.bottom + _screenPadding;
        final maxClusterWidth = math.max(
          220.0,
          viewportWidth - (_screenPadding * 2),
        );
        final bubbleWidth = math.min(details.sourceRect.width, maxClusterWidth);
        final actionWidth = math.min(math.max(bubbleWidth, 220.0), 280.0);
        final clusterWidth = math.min(
          maxClusterWidth,
          math.max(bubbleWidth, actionWidth),
        );
        final clusterHeight = _estimatedClusterHeight;

        final preferredLeft = details.isMe
            ? details.sourceRect.right - clusterWidth
            : details.sourceRect.left;
        final maxLeft = math.max(
          _screenPadding,
          viewportWidth - clusterWidth - _screenPadding,
        );
        final left = preferredLeft.clamp(_screenPadding, maxLeft);

        final availableAbove = details.sourceRect.top - safeTop;
        final availableBelow =
            viewportHeight - safeBottom - details.sourceRect.bottom;
        final showAbove =
            availableBelow < clusterHeight && availableAbove > availableBelow;

        final preferredTop = showAbove
            ? details.sourceRect.top - clusterHeight - 12
            : details.sourceRect.bottom + 12;
        final maxTop = math.max(
          safeTop,
          viewportHeight - safeBottom - clusterHeight,
        );
        final top = preferredTop.clamp(safeTop, maxTop);

        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !visible,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: visible ? 1 : 0),
                  duration: const Duration(milliseconds: 120),
                  curve: const Cubic(0.16, 1, 0.3, 1),
                  builder: (context, value, child) {
                    return Opacity(opacity: value, child: child);
                  },
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onDismiss,
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: ColoredBox(
                        color: CupertinoColors.black.withAlpha(72),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: clusterWidth,
              child: IgnorePointer(
                ignoring: !visible,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: visible ? 1 : 0),
                  duration: const Duration(milliseconds: 150),
                  curve: const Cubic(0.16, 1, 0.3, 1),
                  builder: (context, value, child) {
                    return Opacity(
                      opacity: value,
                      child: Transform.scale(
                        scale: 0.92 + (0.08 * value),
                        alignment: details.isMe
                            ? Alignment.topRight
                            : Alignment.topLeft,
                        child: child,
                      ),
                    );
                  },
                  child: GestureDetector(
                    onTap: () {},
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: details.isMe
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: showAbove
                          ? [
                              _buildActionList(context, colors, actionWidth),
                              const SizedBox(height: _clusterGap),
                              _buildBubblePreview(context, bubbleWidth),
                              if (_showReactionBar) ...[
                                const SizedBox(height: _clusterGap),
                                _buildReactionBar(
                                  context,
                                  colors,
                                  clusterWidth,
                                ),
                              ],
                            ]
                          : [
                              if (_showReactionBar) ...[
                                _buildReactionBar(
                                  context,
                                  colors,
                                  clusterWidth,
                                ),
                                const SizedBox(height: _clusterGap),
                              ],
                              _buildBubblePreview(context, bubbleWidth),
                              const SizedBox(height: _clusterGap),
                              _buildActionList(context, colors, actionWidth),
                            ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  double get _estimatedClusterHeight {
    final actionHeight = actions.length * _actionRowHeight;
    final reactionHeight = _showReactionBar
        ? _reactionBarHeight + _clusterGap
        : 0;
    return reactionHeight + _estimatedBubbleHeight + _clusterGap + actionHeight;
  }

  Widget _buildBubblePreview(BuildContext context, double width) {
    final message = details.message;
    final presentation = MessageBubblePresentation.fromContext(
      context: context,
      message: message,
      isMe: details.isMe,
      chatMessageFontSize: chatMessageFontSize,
    );

    return SizedBox(
      width: width,
      child: MessageBubble(
        message: message,
        presentation: presentation,
        chatMessageFontSize: chatMessageFontSize,
        isMe: details.isMe,
        showSenderName: !details.isMe,
      ),
    );
  }

  Widget _buildReactionBar(
    BuildContext context,
    AppColors colors,
    double width,
  ) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceCard.withAlpha(245),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withAlpha(40),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: quickReactionEmojis
              .map((emoji) {
                final reactedByMe = details.message.reactions.any(
                  (reaction) =>
                      reaction.emoji == emoji && reaction.reactedByMe == true,
                );
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(40, 40),
                    onPressed: () => onToggleReaction(emoji),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: reactedByMe
                            ? CupertinoColors.activeBlue.withAlpha(18)
                            : const Color(0x00000000),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(emoji, style: const TextStyle(fontSize: 24)),
                    ),
                  ),
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }

  Widget _buildActionList(
    BuildContext context,
    AppColors colors,
    double width,
  ) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: colors.surfaceCard.withAlpha(248),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            _buildActionRow(context, actions[i]),
            if (i < actions.length - 1)
              Container(height: 1, color: colors.separator.withAlpha(90)),
          ],
        ],
      ),
    );
  }

  Widget _buildActionRow(BuildContext context, MessageOverlayAction action) {
    final textColor = action.isDestructive
        ? CupertinoColors.systemRed.resolveFrom(context)
        : context.appColors.textPrimary;

    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      minimumSize: Size.fromHeight(_actionRowHeight),
      borderRadius: BorderRadius.zero,
      onPressed: action.onPressed,
      child: Row(
        children: [
          if (action.icon != null) ...[
            Icon(action.icon, color: textColor, size: 20),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              action.label,
              style: appTextStyle(
                context,
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
