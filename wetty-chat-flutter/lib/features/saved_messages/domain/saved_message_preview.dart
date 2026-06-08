import 'package:chahua/core/api/models/saved_messages_api_models.dart';
import 'package:chahua/features/shared/model/message/attachment.dart';
import 'package:chahua/features/shared/model/message/mention.dart';
import 'package:chahua/features/shared/model/message/preview_formatter.dart';
import 'package:chahua/features/shared/model/message/sticker.dart';
import 'package:chahua/l10n/app_localizations.dart';

String formatSavedMessagePreview(
  SavedMessageResponseDto saved,
  AppLocalizations l10n,
) {
  return formatMessagePreview(
    message: saved.message,
    messageType: saved.messageType,
    sticker: _stickerFromSaved(saved.sticker),
    attachments: saved.attachments.map(_attachmentFromSaved).toList(),
    firstAttachmentKind: saved.attachments.isEmpty
        ? null
        : saved.attachments.first.kind,
    mentions: saved.mentions.map(MentionInfo.fromDto).toList(),
    l10n: l10n,
  );
}

AttachmentItem _attachmentFromSaved(SavedAttachmentSnapshotDto attachment) {
  return AttachmentItem(
    id: attachment.id,
    url: attachment.url,
    kind: attachment.kind,
    size: attachment.size,
    fileName: attachment.fileName,
    width: attachment.width,
    height: attachment.height,
  );
}

StickerSummary? _stickerFromSaved(SavedStickerSnapshotDto? sticker) {
  if (sticker == null) {
    return null;
  }
  return StickerSummary(
    id: sticker.id,
    emoji: sticker.emoji,
    name: sticker.name,
  );
}
