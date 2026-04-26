import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/features/conversation/pins/domain/pinned_message.dart';
import 'package:chahua/features/shared/model/message/message.dart';
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
    final preview = _formatConversationMessagePreview(pin.message, l10n);

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
                      _senderName(pin.message.sender, l10n),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: appTextStyle(
                        context,
                        fontSize: AppFontSizes.meta,
                        fontWeight: FontWeight.w600,
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
                        fontSize: AppFontSizes.bodySmall,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              if (onOpenThread != null)
                _BannerIconButton(
                  icon: CupertinoIcons.chat_bubble_2,
                  label: l10n.thread,
                  onPressed: onOpenThread!,
                ),
              if (pinCount > 1)
                _BannerCountButton(count: pinCount, onPressed: onOpenPinList),
              if (canManagePins)
                _BannerIconButton(
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

    return CupertinoPopupSurface(
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.62,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.pinnedMessages,
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
                        CupertinoIcons.xmark,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: pins.length,
                  separatorBuilder: (context, index) => Container(
                    height: 1,
                    margin: const EdgeInsets.only(left: 52),
                    color: colors.separator,
                  ),
                  itemBuilder: (context, index) {
                    final pin = pins[index];
                    return _PinnedMessageListItem(
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
    );
  }
}

class _PinnedMessageListItem extends StatelessWidget {
  const _PinnedMessageListItem({
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
    final preview = _formatConversationMessagePreview(pin.message, l10n);

    return CupertinoButton(
      minimumSize: Size.zero,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onPressed: onOpenPin,
      child: Row(
        children: [
          Icon(CupertinoIcons.pin, size: 20, color: colors.accentPrimary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _senderName(pin.message.sender, l10n),
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
            _BannerIconButton(
              icon: CupertinoIcons.chat_bubble_2,
              label: l10n.thread,
              onPressed: onOpenThread!,
            ),
          if (canManagePins)
            _BannerIconButton(
              icon: CupertinoIcons.xmark,
              label: l10n.unpinMessage,
              onPressed: onUnpin,
            ),
        ],
      ),
    );
  }
}

class _BannerCountButton extends StatelessWidget {
  const _BannerCountButton({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return CupertinoButton(
      minimumSize: Size.zero,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      onPressed: onPressed,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surfaceMuted,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          child: Text(
            count.toString(),
            style: appTextStyle(
              context,
              fontSize: AppFontSizes.meta,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerIconButton extends StatelessWidget {
  const _BannerIconButton({
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

String _senderName(Sender sender, AppLocalizations l10n) {
  final name = sender.name?.trim();
  if (name != null && name.isNotEmpty) {
    return name;
  }
  return l10n.userFallbackName(sender.uid);
}

String _formatConversationMessagePreview(
  ConversationMessageV2 message,
  AppLocalizations l10n,
) {
  if (message.isDeleted) {
    return l10n.previewDeleted;
  }
  return switch (message.content) {
    TextMessageContent(:final text, :final attachments, :final mentions) =>
      formatMessagePreview(
        message: text,
        messageType: 'text',
        attachments: attachments,
        mentions: mentions,
        l10n: l10n,
      ),
    AudioMessageContent(:final text, :final mentions) => formatMessagePreview(
      message: text,
      messageType: 'audio',
      mentions: mentions,
      l10n: l10n,
    ),
    StickerMessageContent(:final sticker) => formatMessagePreview(
      messageType: 'sticker',
      sticker: sticker,
      l10n: l10n,
    ),
    InviteMessageContent(:final text, :final mentions) => formatMessagePreview(
      message: text,
      messageType: 'invite',
      mentions: mentions,
      l10n: l10n,
    ),
    SystemMessageContent(:final text) => formatMessagePreview(
      message: text,
      messageType: 'system',
      l10n: l10n,
    ),
  };
}
