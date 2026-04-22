import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';

import '../../../../app/theme/style_config.dart';
import 'message_long_press_details_v2.dart';

class MessageOverlayActionV2 {
  const MessageOverlayActionV2({
    required this.label,
    required this.onPressed,
    this.icon,
  });

  final String label;
  final VoidCallback onPressed;
  final IconData? icon;
}

class MessageOverlayV2 extends StatelessWidget {
  const MessageOverlayV2({
    super.key,
    required this.details,
    required this.visible,
    required this.actions,
    required this.onDismiss,
  });

  static const double _screenPadding = 16;
  static const double _panelMinWidth = 176;
  static const double _panelMaxWidth = 260;
  static const double _rowHeight = 48;
  static const double _panelGap = 10;

  final MessageLongPressDetailsV2 details;
  final bool visible;
  final List<MessageOverlayActionV2> actions;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaQuery = MediaQuery.of(context);
        final viewportWidth = constraints.maxWidth;
        final viewportHeight = constraints.maxHeight;
        final panelWidth = math.min(
          _panelMaxWidth,
          math.max(_panelMinWidth, viewportWidth - (_screenPadding * 2)),
        );
        final panelHeight = actions.length * _rowHeight;
        final safeTop = mediaQuery.padding.top + _screenPadding;
        final safeBottom = viewportHeight - mediaQuery.padding.bottom - _screenPadding;
        final preferredTop = details.visibleRect.bottom + _panelGap;
        final fallbackTop = details.visibleRect.top - _panelGap - panelHeight;
        final top = (preferredTop + panelHeight <= safeBottom
                ? preferredTop
                : fallbackTop)
            .clamp(safeTop, math.max(safeTop, safeBottom - panelHeight))
            .toDouble();
        final left = (details.isMe
                ? details.visibleRect.right - panelWidth
                : details.visibleRect.left)
            .clamp(
              _screenPadding,
              math.max(_screenPadding, viewportWidth - _screenPadding - panelWidth),
            )
            .toDouble();

        return Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
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
                      child: ColoredBox(
                        color: CupertinoColors.black.withAlpha(56),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: panelWidth,
              child: IgnorePointer(
                ignoring: !visible,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: visible ? 1 : 0),
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) => Opacity(
                    opacity: value,
                    child: Transform.scale(
                      scale: 0.96 + (0.04 * value),
                      alignment: details.isMe
                          ? Alignment.topRight
                          : Alignment.topLeft,
                      child: child,
                    ),
                  ),
                  child: _ActionPanel(actions: actions),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({required this.actions});

  final List<MessageOverlayActionV2> actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            blurRadius: 22,
            offset: Offset(0, 8),
            color: Color(0x22000000),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < actions.length; index++) ...[
              _ActionButton(action: actions[index]),
              if (index < actions.length - 1)
                Container(
                  height: 1,
                  color: CupertinoColors.separator.resolveFrom(context),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action});

  final MessageOverlayActionV2 action;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      minimumSize: const Size(0, 48),
      borderRadius: BorderRadius.zero,
      onPressed: action.onPressed,
      child: Row(
        children: [
          if (action.icon case final icon?) ...[
            Icon(icon, size: 18, color: context.appColors.textPrimary),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Text(
              action.label,
              style: appTextStyle(context, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
