import '../../../core/api/models/messages_api_models.dart';
import 'message_models.dart';

extension SenderDtoMapper on SenderDto {
  Sender toDomain() =>
      Sender(uid: uid, name: name, avatarUrl: avatarUrl, gender: gender);
}

extension AttachmentItemDtoMapper on AttachmentItemDto {
  AttachmentItem toDomain() => AttachmentItem(
    id: id,
    url: url,
    kind: kind,
    size: size,
    fileName: fileName,
    width: width,
    height: height,
  );
}

extension ReplyToMessageDtoMapper on ReplyToMessageDto {
  ReplyToMessage toDomain() => ReplyToMessage(
    id: id,
    message: message,
    sender: sender.toDomain(),
    isDeleted: isDeleted,
  );
}

extension ThreadInfoDtoMapper on ThreadInfoDto {
  ThreadInfo toDomain() => ThreadInfo(replyCount: replyCount);
}

extension MessageItemDtoMapper on MessageItemDto {
  MessageItem toDomain() => MessageItem(
    id: id,
    message: message,
    messageType: messageType,
    sender: sender.toDomain(),
    chatId: chatId.toString(),
    createdAt: createdAt,
    isEdited: isEdited,
    isDeleted: isDeleted,
    clientGeneratedId: clientGeneratedId,
    replyRootId: replyRootId,
    hasAttachments: hasAttachments,
    replyToMessage: replyToMessage?.toDomain(),
    attachments: attachments
        .map((attachment) => attachment.toDomain())
        .toList(),
    threadInfo: threadInfo?.toDomain(),
  );
}
