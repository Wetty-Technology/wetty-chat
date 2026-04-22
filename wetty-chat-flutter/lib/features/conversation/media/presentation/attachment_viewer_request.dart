import 'package:chahua/features/chats/models/message_models.dart';

enum AttachmentViewerMediaKind { image, video }

class AttachmentViewerItem {
  const AttachmentViewerItem({
    required this.attachment,
    required this.heroTag,
    required this.mediaKind,
  });

  final AttachmentItem attachment;
  final String heroTag;
  final AttachmentViewerMediaKind mediaKind;

  bool get isImage => mediaKind == AttachmentViewerMediaKind.image;
  bool get isVideo => mediaKind == AttachmentViewerMediaKind.video;
}

class AttachmentViewerRequest {
  const AttachmentViewerRequest({
    required this.items,
    required this.initialIndex,
  }) : assert(items.length > 0),
       assert(initialIndex >= 0),
       assert(initialIndex < items.length);

  final List<AttachmentViewerItem> items;
  final int initialIndex;
}

class MessageAttachmentOpenRequest {
  const MessageAttachmentOpenRequest({
    required this.attachment,
    this.viewerRequest,
  });

  final AttachmentItem attachment;
  final AttachmentViewerRequest? viewerRequest;
}

String attachmentViewerHeroTag({
  required String messageStableKey,
  required AttachmentItem attachment,
}) {
  final attachmentKey = attachment.id.isNotEmpty
      ? attachment.id
      : attachment.url;
  return 'attachment-viewer:$messageStableKey:$attachmentKey';
}

AttachmentViewerRequest? buildAttachmentViewerRequest({
  required String messageStableKey,
  required List<AttachmentItem> attachments,
  required AttachmentItem tappedAttachment,
}) {
  final mediaAttachments = attachments
      .where(
        (attachment) =>
            attachment.url.isNotEmpty &&
            (attachment.isImage || attachment.isVideo),
      )
      .toList(growable: false);
  if (mediaAttachments.isEmpty) {
    return null;
  }

  final initialIndex = mediaAttachments.indexWhere(
    (attachment) =>
        (attachment.id.isNotEmpty && attachment.id == tappedAttachment.id) ||
        attachment.url == tappedAttachment.url,
  );
  if (initialIndex < 0) {
    return null;
  }

  return AttachmentViewerRequest(
    items: mediaAttachments
        .map(
          (attachment) => AttachmentViewerItem(
            attachment: attachment,
            heroTag: attachmentViewerHeroTag(
              messageStableKey: messageStableKey,
              attachment: attachment,
            ),
            mediaKind: attachment.isVideo
                ? AttachmentViewerMediaKind.video
                : AttachmentViewerMediaKind.image,
          ),
        )
        .toList(growable: false),
    initialIndex: initialIndex,
  );
}
