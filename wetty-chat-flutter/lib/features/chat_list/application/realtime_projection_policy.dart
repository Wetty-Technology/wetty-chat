import 'package:chahua/core/api/models/messages_api_models.dart';
import 'package:chahua/features/shared/model/message/message.dart';

bool isEligibleChatPreviewPayload(MessageItemDto payload) {
  return payload.replyRootId == null && !payload.isDeleted;
}

bool isEligibleThreadPreviewPayload(MessageItemDto payload) {
  return payload.replyRootId != null && !payload.isDeleted;
}

bool matchesChatPreview(MessageItem? preview, MessageItemDto payload) {
  if (preview == null) {
    return false;
  }
  if (preview.id == payload.id) {
    return true;
  }
  return preview.clientGeneratedId.isNotEmpty &&
      preview.clientGeneratedId == payload.clientGeneratedId;
}

bool matchesThreadPreview(MessagePreview? preview, MessageItemDto payload) {
  if (preview == null) {
    return false;
  }
  if (preview.messageId != null) {
    return preview.messageId == payload.id;
  }
  final clientGeneratedId = preview.clientGeneratedId;
  return clientGeneratedId != null &&
      clientGeneratedId.isNotEmpty &&
      clientGeneratedId == payload.clientGeneratedId;
}
