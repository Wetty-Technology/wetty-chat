import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/features/conversation/pins/domain/pinned_message.dart';
import 'package:chahua/features/conversation/pins/presentation/pinned_message_action_button.dart';
import 'package:chahua/features/conversation/pins/presentation/pinned_message_preview_text.dart';
import 'package:chahua/l10n/app_localizations.dart';
import 'package:flutter/cupertino.dart';

class PinnedMessageBanner extends StatelessWidget {
  const PinnedMessageBanner({
    super.key,
    required this.pin,
    required this.pinCount,
    required this.canManagePins,
    required this.onOpenPin,
    required this.onOpenPinList,
    required this.onUnpin,
    this.onOpenThread,
  });

  final PinnedMessage pin;
  final int pinCount;
  final bool canManagePins;
  final VoidCallback onOpenPin;
  final VoidCallback onOpenPinList;
  final VoidCallback onUnpin;
  final VoidCallback? onOpenThread;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context)!;
    final preview = formatPinnedMessagePreview(pin.message, l10n);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.backgroundSecondary,
        border: Border(bottom: BorderSide(color: colors.separator)),
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: CupertinoButton(
          minimumSize: Size.zero,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          onPressed: onOpenPin,
          child: Row(
            children: [
              Icon(
                CupertinoIcons.pin_fill,
                size: 18,
                color: colors.accentPrimary,
              ),
              const SizedBox(width: 8),
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
                        fontSize: AppFontSizes.meta,
                        fontWeight: AppFontWeights.semibold,
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      preview.isEmpty ? l10n.message : preview,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: appTextStyle(
                        context,
                        fontSize: AppFontSizes.meta,
                        color: colors.textPrimary,
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
              if (pinCount > 1)
                PinnedMessageCountButton(
                  count: pinCount,
                  onPressed: onOpenPinList,
                ),
              if (canManagePins)
                PinnedMessageIconButton(
                  icon: CupertinoIcons.xmark,
                  label: l10n.unpinMessage,
                  onPressed: onUnpin,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
