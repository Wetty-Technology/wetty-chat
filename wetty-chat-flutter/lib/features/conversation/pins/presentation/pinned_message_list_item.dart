import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/features/conversation/pins/domain/pinned_message.dart';
import 'package:chahua/features/conversation/pins/presentation/pinned_message_action_button.dart';
import 'package:chahua/features/conversation/pins/presentation/pinned_message_preview_text.dart';
import 'package:chahua/l10n/app_localizations.dart';
import 'package:flutter/cupertino.dart';

class PinnedMessageListItem extends StatelessWidget {
  const PinnedMessageListItem({
    super.key,
    required this.pin,
    required this.canManagePins,
    required this.onOpenPin,
    required this.onUnpin,
    this.onOpenThread,
  });

  final PinnedMessage pin;
  final bool canManagePins;
  final VoidCallback onOpenPin;
  final VoidCallback onUnpin;
  final VoidCallback? onOpenThread;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context)!;
    final preview = formatPinnedMessagePreview(pin.message, l10n);

    return CupertinoButton(
      minimumSize: Size.zero,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      onPressed: onOpenPin,
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: Icon(
                CupertinoIcons.pin,
                size: 18,
                color: colors.accentPrimary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  pinnedMessageSenderName(pin.message.sender, l10n),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appTextStyle(
                    context,
                    fontSize: AppFontSizes.bodySmall,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  preview.isEmpty ? l10n.message : preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: appTextStyle(
                    context,
                    fontSize: AppFontSizes.bodySmall,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (onOpenThread != null)
            PinnedMessageIconButton(
              icon: CupertinoIcons.chat_bubble_2,
              label: l10n.thread,
              onPressed: onOpenThread!,
            ),
          if (canManagePins)
            PinnedMessageIconButton(
              icon: CupertinoIcons.xmark,
              label: l10n.unpinMessage,
              onPressed: onUnpin,
            ),
        ],
      ),
    );
  }
}
