import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/features/shared/presentation/app_avatar.dart';
import 'package:chahua/features/shared/model/message/message.dart';
import 'package:flutter/cupertino.dart';

import '../../domain/bubble_theme_v2.dart';

class BubbleReactions extends StatelessWidget {
  const BubbleReactions({
    super.key,
    required this.reactions,
    this.interactive,
    this.onToggleReaction,
  });

  static const int _maxVisibleReactors = 5;
  static const double _reactionPillHorizontalPadding = 8;
  static const double _reactionPillGap = 6;
  static const double _reactionEmojiFontSize = 18.5;
  static const FontWeight _bubbleFontWeight = FontWeight.w400;

  final List<ReactionSummary> reactions;

  /// When null, reactions follow `BubbleThemeV2.isInteractive`.
  /// When `false`, reactions are non-interactive regardless of theme
  /// (used by sticker bubbles).
  final bool? interactive;
  final ValueChanged<String>? onToggleReaction;

  Color _reactionPillBackground(
    BuildContext context,
    BubbleThemeV2 theme,
    ReactionSummary reaction,
  ) {
    final colors = context.appColors;
    if (theme.isMe) {
      return reaction.reactedByMe == true
          ? colors.chatReactionSentActive
          : colors.chatReactionSent;
    }
    return reaction.reactedByMe == true
        ? colors.chatReactionReceivedActive
        : colors.chatReactionReceived;
  }

  Color _reactionPillForeground(
    BuildContext context,
    BubbleThemeV2 theme,
    ReactionSummary reaction,
  ) {
    if (theme.isMe || reaction.reactedByMe == true) {
      return context.appColors.textOnAccent;
    }
    return context.appColors.textPrimary;
  }

  double _measureTextWidth(
    BuildContext context,
    String text, {
    required double fontSize,
    required FontWeight fontWeight,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: appBubbleTextStyle(
          context,
          fontSize: fontSize,
          fontWeight: fontWeight,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: double.infinity);
    return painter.width;
  }

  double _estimateReactionPillWidth(
    BuildContext context,
    ReactionSummary reaction,
  ) {
    var width = _reactionPillHorizontalPadding * 2;
    width += _measureTextWidth(
      context,
      reaction.emoji,
      fontSize: _reactionEmojiFontSize,
      fontWeight: _bubbleFontWeight,
    );

    final reactors = reaction.reactors;
    if (reactors != null && reactors.isNotEmpty) {
      final visibleReactors = reactors.length.clamp(0, _maxVisibleReactors);
      width += 4;
      width += _ReactionReactorStrip.avatarStackWidth(visibleReactors);
      if (reaction.count > _maxVisibleReactors) {
        width += 2;
        width += _measureTextWidth(
          context,
          '+${reaction.count - _maxVisibleReactors}',
          fontSize: 11,
          fontWeight: FontWeight.w600,
        );
      }
      return width;
    }

    if (reaction.count > 1) {
      width += 4;
      width += _measureTextWidth(
        context,
        '${reaction.count}',
        fontSize: AppFontSizes.meta,
        fontWeight: FontWeight.w600,
      );
    }

    return width;
  }

  double _preferredReactionRowWidth(
    BuildContext context,
    double maxBubbleWidth,
  ) {
    final maxContentWidth = maxBubbleWidth - 24;
    if (reactions.isEmpty) {
      return maxContentWidth;
    }

    var width = 0.0;
    for (var index = 0; index < reactions.length; index++) {
      if (index > 0) {
        width += _reactionPillGap;
      }
      width += _estimateReactionPillWidth(context, reactions[index]);
    }

    return width.clamp(0.0, maxContentWidth);
  }

  @override
  Widget build(BuildContext context) {
    final theme = BubbleThemeV2.of(context);
    final isInteractive = interactive ?? theme.isInteractive;
    final pills = reactions
        .map((reaction) {
          final pillBackground = _reactionPillBackground(
            context,
            theme,
            reaction,
          );
          final pillForeground = _reactionPillForeground(
            context,
            theme,
            reaction,
          );

          final pill = Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: pillBackground,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  reaction.emoji,
                  style: appBubbleTextStyle(
                    context,
                    color: pillForeground,
                    fontSize: _reactionEmojiFontSize,
                    fontWeight: _bubbleFontWeight,
                  ),
                ),
                if (reaction.reactors != null &&
                    reaction.reactors!.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  _ReactionReactorStrip(
                    reactors: reaction.reactors!,
                    count: reaction.count,
                    borderColor: pillForeground,
                    textColor: pillForeground,
                  ),
                ] else if (reaction.count > 1) ...[
                  const SizedBox(width: 4),
                  Text(
                    '${reaction.count}',
                    style: appBubbleTextStyle(
                      context,
                      color: pillForeground.withAlpha(179),
                      fontSize: AppFontSizes.meta,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          );

          if (!isInteractive) {
            return pill;
          }

          return GestureDetector(
            onTap: () => onToggleReaction?.call(reaction.emoji),
            child: pill,
          );
        })
        .toList(growable: false);

    return SizedBox(
      width: _preferredReactionRowWidth(context, theme.maxBubbleWidth),
      child: Wrap(
        spacing: _reactionPillGap,
        runSpacing: _reactionPillGap,
        children: pills,
      ),
    );
  }
}

class _ReactionReactorStrip extends StatelessWidget {
  const _ReactionReactorStrip({
    required this.reactors,
    required this.count,
    required this.borderColor,
    required this.textColor,
  });

  static const double _avatarSize = 23;
  static const double _avatarOverlap = 9;

  static double avatarStackWidth(int visibleCount) {
    if (visibleCount <= 0) {
      return 0;
    }
    return _avatarSize + (visibleCount - 1) * (_avatarSize - _avatarOverlap);
  }

  final List<ReactionReactor> reactors;
  final int count;
  final Color borderColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final visibleReactors = reactors
        .take(BubbleReactions._maxVisibleReactors)
        .toList(growable: false);
    final stackWidth = avatarStackWidth(visibleReactors.length);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: stackWidth,
          height: _avatarSize,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var index = visibleReactors.length - 1; index >= 0; index--)
                Positioned(
                  left: index * (_avatarSize - _avatarOverlap),
                  child: _ReactionReactorAvatar(
                    reactor: visibleReactors[index],
                    size: _avatarSize,
                    borderColor: borderColor,
                  ),
                ),
            ],
          ),
        ),
        if (count > BubbleReactions._maxVisibleReactors) ...[
          const SizedBox(width: 2),
          Text(
            '+${count - BubbleReactions._maxVisibleReactors}',
            style: appBubbleTextStyle(
              context,
              color: textColor.withAlpha(204),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _ReactionReactorAvatar extends StatelessWidget {
  const _ReactionReactorAvatar({
    required this.reactor,
    required this.size,
    required this.borderColor,
  });

  final ReactionReactor reactor;
  final double size;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: ClipOval(
        child: AppAvatar(
          imageUrl: reactor.avatarUrl,
          name: reactor.name,
          size: size,
        ),
      ),
    );
  }
}
