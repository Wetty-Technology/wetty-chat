import '../../../../core/api/models/messages_api_models.dart';
import '../../models/message_api_mapper.dart';
import '../models/conversation_models.dart';

extension ConversationMessageItemDtoMapper on MessageItemDto {
  ConversationMessage toConversationMessage(ConversationScope scope) {
    return ConversationMessage(
      serverId: id,
      clientGeneratedId: clientGeneratedId,
      scope: scope,
      message: message,
      messageType: messageType,
      sender: sender.toDomain(),
      createdAt: createdAt,
      isEdited: isEdited,
      isDeleted: isDeleted,
      replyRootId: replyRootId,
      hasAttachments: hasAttachments,
      replyToMessage: replyToMessage?.toDomain(),
      attachments: attachments
          .map((attachment) => attachment.toDomain())
          .toList(),
      threadInfo: threadInfo?.toDomain(),
    );
  }
}
