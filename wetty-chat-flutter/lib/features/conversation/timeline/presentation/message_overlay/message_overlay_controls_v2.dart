import 'package:chahua/app/theme/style_config.dart';
import 'package:flutter/cupertino.dart';

import 'message_overlay_action_v2.dart';

class MessageOverlayReactionBarV2 extends StatelessWidget {
  const MessageOverlayReactionBarV2({
    super.key,
    required this.emojis,
    required this.onToggleReaction,
  });

  final List<String> emojis;
  final ValueChanged<String> onToggleReaction;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: colors.backgroundSecondary,
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            blurRadius: 18,
            offset: Offset(0, 6),
            color: Color(0x22000000),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final emoji in emojis)
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              minimumSize: const Size(0, 0),
              onPressed: () => onToggleReaction(emoji),
              child: Text(emoji, style: const TextStyle(fontSize: 24)),
            ),
        ],
      ),
    );
  }
}

class MessageOverlayActionPanelV2 extends StatelessWidget {
  const MessageOverlayActionPanelV2({super.key, required this.actions});

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
              style: appBodyTextStyle(
                context,
                fontWeight: AppFontWeights.medium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
