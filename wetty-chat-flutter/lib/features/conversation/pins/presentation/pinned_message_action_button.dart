import 'package:chahua/app/theme/style_config.dart';
import 'package:flutter/cupertino.dart';

class PinnedMessageCountButton extends StatelessWidget {
  const PinnedMessageCountButton({
    super.key,
    required this.count,
    required this.onPressed,
  });

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      onPressed: onPressed,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          border: Border.all(color: colors.separator),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                CupertinoIcons.list_bullet,
                size: 15,
                color: colors.accentPrimary,
              ),
              const SizedBox(width: 4),
              Text(
                count.toString(),
                style: appTextStyle(
                  context,
                  fontSize: AppFontSizes.meta,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PinnedMessageIconButton extends StatelessWidget {
  const PinnedMessageIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: const EdgeInsets.all(8),
      onPressed: onPressed,
      child: Icon(
        icon,
        semanticLabel: label,
        size: 19,
        color: context.appColors.textSecondary,
      ),
    );
  }
}
