import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';

import '../../../../app/theme/style_config.dart';
import '../../../../core/network/api_config.dart';
import 'message_bubble/message_bubble.dart';
import 'message_bubble/message_bubble_presentation.dart';
import 'message_overlay_preview.dart';
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

class _OverlayPlacement {
  const _OverlayPlacement({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.contentOffset = Offset.zero,
    this.allowsActionOverlap = false,
  });

  final double left;
  final double top;
  final double width;
  final double height;
  final Offset contentOffset;
  final bool allowsActionOverlap;
}

class _OverlayLayout {
  const _OverlayLayout({
    required this.preview,
    required this.actionTop,
    required this.actionWidth,
    required this.reactionTop,
    required this.actionsPinnedToBottom,
  });

  final _OverlayPlacement preview;
  final double actionTop;
  final double actionWidth;
  final double? reactionTop;
  final bool actionsPinnedToBottom;
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
  static const double _actionRowHeight = 52;
  static const double _actionSheetMinWidth = 148;
  static const double _actionSheetMaxWidth = 240;
  static const double _actionRowHorizontalPadding = 14;
  static const double _actionIconSize = 20;
  static const double _actionIconGap = 10;
  static const double _minTallPreviewLines = 4;
  static const double _bubbleVerticalPadding = 16;
  static const double _senderHeaderHeight = 20;
  static const double _overlayReactionBarWidth = 236;

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
        final bottomLimit = viewportHeight - safeBottom;
        final maxPanelWidth = math.max(
          220.0,
          viewportWidth - (_screenPadding * 2),
        );
        final bubbleRect = Rect.fromLTWH(
          details.bubbleRect.left.clamp(0.0, viewportWidth).toDouble(),
          details.bubbleRect.top.clamp(0.0, viewportHeight).toDouble(),
          details.bubbleRect.width.clamp(0.0, viewportWidth).toDouble(),
          details.bubbleRect.height.clamp(0.0, viewportHeight).toDouble(),
        );
        final actionWidth = _measureActionWidth(
          context,
          maxWidth: viewportWidth - (_screenPadding * 2),
        );
        final overlayLayout = _resolveOverlayLayout(
          bubbleRect: bubbleRect,
          safeTop: safeTop,
          safeBottom: bottomLimit,
          viewportWidth: viewportWidth,
          actionWidth: actionWidth,
        );
        final previewPlacement = overlayLayout.preview;
        final reactionWidth = math.min(_overlayReactionBarWidth, maxPanelWidth);
        final panelAnchorRect = Rect.fromLTWH(
          previewPlacement.left,
          previewPlacement.top,
          previewPlacement.width,
          previewPlacement.height,
        );
        final reactionLeft = _alignedPanelLeft(
          bubbleRect: panelAnchorRect,
          panelWidth: reactionWidth,
          viewportWidth: viewportWidth,
        );
        final actionLeft = _alignedPanelLeft(
          bubbleRect: panelAnchorRect,
          panelWidth: actionWidth,
          viewportWidth: viewportWidth,
        );
        final reactionTop = overlayLayout.reactionTop;
        final actionTop = overlayLayout.actionTop;

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
            if (_showReactionBar && reactionTop != null)
              _buildPositionedOverlayItem(
                left: reactionLeft,
                top: reactionTop,
                width: reactionWidth,
                alignment: details.isMe
                    ? Alignment.bottomRight
                    : Alignment.bottomLeft,
                child: _buildReactionBar(context, colors, reactionWidth),
              ),
            _buildPositionedOverlayItem(
              left: previewPlacement.left,
              top: previewPlacement.top,
              width: previewPlacement.width,
              height: previewPlacement.height,
              alignment: details.isMe
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: _buildBubblePreview(
                context,
                previewPlacement: previewPlacement,
              ),
            ),
            _buildPositionedOverlayItem(
              left: actionLeft,
              top: actionTop,
              width: actionWidth,
              alignment: details.isMe ? Alignment.topRight : Alignment.topLeft,
              child: _buildActionList(context, colors, actionWidth),
            ),
          ],
        );
      },
    );
  }

  double _actionListHeight(int count) {
    if (count <= 0) {
      return 0;
    }
    return (count * _actionRowHeight) + math.max(0, count - 1);
  }

  double _measureActionWidth(BuildContext context, {required double maxWidth}) {
    var widestRowWidth = 0.0;

    for (final action in actions) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: action.label,
          style: appTextStyle(context, fontWeight: FontWeight.w500),
        ),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: double.infinity);

      var rowWidth = _actionRowHorizontalPadding * 2;
      if (action.icon != null) {
        rowWidth += _actionIconSize + _actionIconGap;
      }
      rowWidth += textPainter.width;
      widestRowWidth = math.max(widestRowWidth, rowWidth);
    }

    return widestRowWidth
        .clamp(_actionSheetMinWidth, math.min(_actionSheetMaxWidth, maxWidth))
        .toDouble();
  }

  _OverlayLayout _resolveOverlayLayout({
    required Rect bubbleRect,
    required double safeTop,
    required double safeBottom,
    required double viewportWidth,
    required double actionWidth,
  }) {
    final actionHeight = _actionListHeight(actions.length);
    final reservedTop = _showReactionBar
        ? _reactionBarHeight + _clusterGap
        : 0.0;
    final actionTop = math.max(safeTop, safeBottom - actionHeight);
    final previewMinTop = safeTop + reservedTop;
    final previewMaxBottomWithoutOverlap = actionTop - _clusterGap;
    final availableHeightWithoutOverlap = math.max(
      0.0,
      previewMaxBottomWithoutOverlap - previewMinTop,
    );
    final maxAllowedPreviewBottom = actionTop + actionHeight;
    final availableHeightWithOverlap = math.max(
      0.0,
      maxAllowedPreviewBottom - previewMinTop,
    );
    final minVisiblePreviewHeight = _minimumVisiblePreviewHeight();
    final previewWidth = math.min(
      bubbleRect.width,
      math.max(0.0, viewportWidth - (_screenPadding * 2)),
    );
    final horizontalClipOffset = details.isMe
        ? math.max(0.0, bubbleRect.width - previewWidth)
        : 0.0;

    final previewLeft = _alignedPanelLeft(
      bubbleRect: Rect.fromLTWH(
        bubbleRect.left,
        bubbleRect.top,
        previewWidth,
        bubbleRect.height,
      ),
      panelWidth: previewWidth,
      viewportWidth: viewportWidth,
    );

    late final _OverlayPlacement preview;
    if (bubbleRect.height <= availableHeightWithoutOverlap) {
      final previewTop = bubbleRect.top
          .clamp(
            previewMinTop,
            math.max(
              previewMinTop,
              previewMaxBottomWithoutOverlap - bubbleRect.height,
            ),
          )
          .toDouble();
      preview = _OverlayPlacement(
        left: previewLeft,
        top: previewTop,
        width: previewWidth,
        height: bubbleRect.height,
        contentOffset: Offset(horizontalClipOffset, 0),
      );

      return _OverlayLayout(
        preview: preview,
        actionTop: preview.top + preview.height + _clusterGap,
        actionWidth: actionWidth,
        reactionTop: _showReactionBar
            ? preview.top - _clusterGap - _reactionBarHeight
            : null,
        actionsPinnedToBottom: false,
      );
    } else {
      final previewHeight = math.min(
        bubbleRect.height,
        availableHeightWithOverlap,
      );
      final resolvedPreviewHeight = math.max(
        math.min(previewHeight, bubbleRect.height),
        math.min(minVisiblePreviewHeight, previewHeight),
      );
      final previewTop = bubbleRect.top
          .clamp(
            previewMinTop,
            math.max(
              previewMinTop,
              maxAllowedPreviewBottom - resolvedPreviewHeight,
            ),
          )
          .toDouble();

      preview = _OverlayPlacement(
        left: previewLeft,
        top: previewTop,
        width: previewWidth,
        height: resolvedPreviewHeight,
        contentOffset: Offset(horizontalClipOffset, 0),
        allowsActionOverlap: true,
      );

      return _OverlayLayout(
        preview: preview,
        actionTop: actionTop,
        actionWidth: actionWidth,
        reactionTop: _showReactionBar
            ? preview.top - _clusterGap - _reactionBarHeight
            : null,
        actionsPinnedToBottom: true,
      );
    }
  }

  double _minimumVisiblePreviewHeight() {
    final lineHeight = chatMessageFontSize * 1.28;
    final senderHeaderAllowance = details.isMe ? 0.0 : _senderHeaderHeight;
    return _bubbleVerticalPadding +
        senderHeaderAllowance +
        (lineHeight * _minTallPreviewLines);
  }

  double _alignedPanelLeft({
    required Rect bubbleRect,
    required double panelWidth,
    required double viewportWidth,
  }) {
    final preferredLeft = details.isMe
        ? bubbleRect.right - panelWidth
        : bubbleRect.left;
    final maxLeft = math.max(
      _screenPadding,
      viewportWidth - panelWidth - _screenPadding,
    );
    return preferredLeft.clamp(_screenPadding, maxLeft).toDouble();
  }

  Widget _buildPositionedOverlayItem({
    required double left,
    required double top,
    required double width,
    double? height,
    required Alignment alignment,
    required Widget child,
  }) {
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: IgnorePointer(
        ignoring: !visible,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: visible ? 1 : 0),
          duration: const Duration(milliseconds: 150),
          curve: const Cubic(0.16, 1, 0.3, 1),
          builder: (context, value, _) {
            return Opacity(
              opacity: value,
              child: Transform.scale(
                scale: 0.92 + (0.08 * value),
                alignment: alignment,
                child: child,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBubblePreview(
    BuildContext context, {
    required _OverlayPlacement previewPlacement,
  }) {
    final message = details.message;
    final presentation = MessageBubblePresentation.fromContext(
      context: context,
      message: message,
      isMe: details.isMe,
      chatMessageFontSize: chatMessageFontSize,
      maxBubbleWidth: details.bubbleRect.width,
    );

    if (previewPlacement.allowsActionOverlap) {
      return MessageOverlayPreview(
        message: message,
        presentation: presentation,
        chatMessageFontSize: chatMessageFontSize,
        isMe: details.isMe,
        showSenderName: !details.isMe,
        maxHeight: previewPlacement.height,
      );
    }

    return ClipRect(
      child: Transform.translate(
        offset: -previewPlacement.contentOffset,
        child: SizedBox(
          width: details.bubbleRect.width,
          child: MessageBubble(
            message: message,
            presentation: presentation,
            chatMessageFontSize: chatMessageFontSize,
            isMe: details.isMe,
            showSenderName: !details.isMe,
            currentUserId: ApiSession.currentUserId,
          ),
        ),
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
