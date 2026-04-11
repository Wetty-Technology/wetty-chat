import 'message_models.dart';

const String deletedPreviewLabel = '[Deleted]';
const String invitePreviewLabel = '[Invite]';
const String stickerPreviewLabel = '[Sticker]';
const String voiceMessagePreviewLabel = '[Voice message]';
const String imagePreviewLabel = '[Image]';
const String videoPreviewLabel = '[Video]';
const String attachmentPreviewLabel = '[Attachment]';

String formatReplyPreview(ReplyToMessage preview) {
  return formatMessagePreview(
    message: preview.message,
    messageType: preview.messageType,
    sticker: preview.sticker,
    attachments: preview.attachments,
    firstAttachmentKind: preview.firstAttachmentKind,
    isDeleted: preview.isDeleted,
    mentions: preview.mentions,
  );
}

String formatMessagePreview({
  String? message,
  String? messageType,
  StickerSummary? sticker,
  List<AttachmentItem> attachments = const <AttachmentItem>[],
  String? firstAttachmentKind,
  bool isDeleted = false,
  List<MentionInfo> mentions = const <MentionInfo>[],
}) {
  if (isDeleted) {
    return deletedPreviewLabel;
  }

  if (messageType == 'invite') {
    return invitePreviewLabel;
  }

  if (messageType == 'sticker') {
    final emoji = sticker?.emoji?.trim();
    return emoji == null || emoji.isEmpty
        ? stickerPreviewLabel
        : '$stickerPreviewLabel $emoji';
  }

  if (messageType == 'audio') {
    return voiceMessagePreviewLabel;
  }

  final text = message?.trim();
  if (text != null && text.isNotEmpty) {
    return renderMentionsAsText(text, mentions);
  }

  if (_containsAttachmentKind(attachments, 'audio/') ||
      (firstAttachmentKind?.startsWith('audio/') ?? false)) {
    return voiceMessagePreviewLabel;
  }

  if (_containsAttachmentKind(attachments, 'image/') ||
      (firstAttachmentKind?.startsWith('image/') ?? false)) {
    return imagePreviewLabel;
  }

  if (_containsAttachmentKind(attachments, 'video/') ||
      (firstAttachmentKind?.startsWith('video/') ?? false)) {
    return videoPreviewLabel;
  }

  if (attachments.isNotEmpty || firstAttachmentKind != null) {
    return attachmentPreviewLabel;
  }

  return '';
}

bool _containsAttachmentKind(List<AttachmentItem> attachments, String prefix) {
  return attachments.any((attachment) => attachment.kind.startsWith(prefix));
}

String renderMentionsAsText(String text, List<MentionInfo> mentions) {
  if (mentions.isEmpty) {
    return text;
  }

  final mentionMap = <int, String>{};
  for (final mention in mentions) {
    final username = mention.username;
    if (username != null && username.isNotEmpty) {
      mentionMap[mention.uid] = username;
    }
  }

  return text.replaceAllMapped(RegExp(r'@\[uid:(\d+)\]'), (match) {
    final uid = int.tryParse(match.group(1) ?? '');
    if (uid == null) {
      return match.group(0) ?? '';
    }
    return '@${mentionMap[uid] ?? 'User $uid'}';
  });
}
