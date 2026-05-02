import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/features/conversation/pins/domain/pinned_message.dart';
import 'package:chahua/features/conversation/pins/presentation/pinned_message_list_item.dart';
import 'package:chahua/l10n/app_localizations.dart';
import 'package:flutter/cupertino.dart';

class PinnedMessageListModal extends StatefulWidget {
  const PinnedMessageListModal({
    super.key,
    required this.pins,
    required this.canManagePins,
    required this.onOpenPin,
    required this.onConfirmUnpin,
    this.onOpenThread,
  });

  final List<PinnedMessage> pins;
  final bool canManagePins;
  final ValueChanged<PinnedMessage> onOpenPin;
  final Future<void> Function(PinnedMessage pin) onConfirmUnpin;
  final ValueChanged<PinnedMessage>? onOpenThread;

  @override
  State<PinnedMessageListModal> createState() => _PinnedMessageListModalState();
}

class _PinnedMessageListModalState extends State<PinnedMessageListModal> {
  late List<PinnedMessage> _pins;

  @override
  void initState() {
    super.initState();
    _pins = widget.pins;
  }

  @override
  void didUpdateWidget(covariant PinnedMessageListModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pins != widget.pins) {
      _pins = widget.pins;
    }
  }

  void _confirmUnpin(PinnedMessage pin) {
    final l10n = AppLocalizations.of(context)!;
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(l10n.unpinMessageTitle),
        content: Text(l10n.unpinMessageBody),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              _optimisticallyUnpin(pin);
            },
            child: Text(l10n.unpinMessage),
          ),
        ],
      ),
    );
  }

  Future<void> _optimisticallyUnpin(PinnedMessage pin) async {
    final previousPins = _pins;
    setState(() {
      _pins = _pins.where((item) => item.id != pin.id).toList(growable: false);
    });
    try {
      await widget.onConfirmUnpin(pin);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _pins = previousPins;
      });
    }
  }

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
                            fontWeight: AppFontWeights.semibold,
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
                    itemCount: _pins.length,
                    separatorBuilder: (context, index) => Container(
                      height: 1,
                      margin: const EdgeInsets.only(left: 62),
                      color: colors.separator,
                    ),
                    itemBuilder: (context, index) {
                      final pin = _pins[index];
                      return PinnedMessageListItem(
                        pin: pin,
                        canManagePins: widget.canManagePins,
                        onOpenPin: () => widget.onOpenPin(pin),
                        onUnpin: () => _confirmUnpin(pin),
                        onOpenThread:
                            pin.message.threadInfo != null &&
                                (pin.message.threadInfo?.replyCount ?? 0) > 0 &&
                                widget.onOpenThread != null
                            ? () => widget.onOpenThread!(pin)
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
