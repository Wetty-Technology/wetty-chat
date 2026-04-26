import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/features/conversation/pins/domain/pinned_message.dart';
import 'package:chahua/features/conversation/pins/presentation/pinned_message_list_item.dart';
import 'package:chahua/l10n/app_localizations.dart';
import 'package:flutter/cupertino.dart';

class PinnedMessageListModal extends StatelessWidget {
  const PinnedMessageListModal({
    super.key,
    required this.pins,
    required this.canManagePins,
    required this.onOpenPin,
    required this.onUnpin,
    this.onOpenThread,
  });

  final List<PinnedMessage> pins;
  final bool canManagePins;
  final ValueChanged<PinnedMessage> onOpenPin;
  final ValueChanged<PinnedMessage> onUnpin;
  final ValueChanged<PinnedMessage>? onOpenThread;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context)!;
    final borderRadius = const BorderRadius.vertical(top: Radius.circular(16));

    return ClipRRect(
      borderRadius: borderRadius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.backgroundSecondary,
          borderRadius: borderRadius,
          border: Border(top: BorderSide(color: colors.separator)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.62,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.separator,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: const SizedBox(width: 36, height: 4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
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
                            CupertinoIcons.pin_fill,
                            size: 18,
                            color: colors.accentPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.pinnedMessages,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: appTextStyle(
                            context,
                            fontSize: AppFontSizes.sectionTitle,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      CupertinoButton(
                        minimumSize: Size.zero,
                        padding: const EdgeInsets.all(8),
                        onPressed: () => Navigator.pop(context),
                        child: Icon(
                          CupertinoIcons.xmark_circle_fill,
                          size: 24,
                          color: colors.inactive,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(height: 1, color: colors.separator),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: pins.length,
                    separatorBuilder: (context, index) => Container(
                      height: 1,
                      margin: const EdgeInsets.only(left: 62),
                      color: colors.separator,
                    ),
                    itemBuilder: (context, index) {
                      final pin = pins[index];
                      return PinnedMessageListItem(
                        pin: pin,
                        canManagePins: canManagePins,
                        onOpenPin: () => onOpenPin(pin),
                        onUnpin: () => onUnpin(pin),
                        onOpenThread:
                            pin.message.threadInfo != null &&
                                (pin.message.threadInfo?.replyCount ?? 0) > 0 &&
                                onOpenThread != null
                            ? () => onOpenThread!(pin)
                            : null,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
