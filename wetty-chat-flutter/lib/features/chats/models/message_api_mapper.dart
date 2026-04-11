import '../../../core/api/models/messages_api_models.dart';
import '../conversation/domain/conversation_message.dart';
import '../conversation/domain/conversation_scope.dart';
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

extension StickerMediaDtoMapper on StickerMediaDto {
  StickerMedia toDomain() => StickerMedia(
    id: id,
    url: url,
    contentType: contentType,
    size: size,
    width: width,
    height: height,
  );
}

extension StickerSummaryDtoMapper on StickerSummaryDto {
  StickerSummary toDomain() => StickerSummary(
    id: id,
    media: media?.toDomain(),
    emoji: emoji,
    name: name,
    description: description,
    createdAt: createdAt,
    isFavorited: isFavorited,
  );
}

extension ReactionReactorDtoMapper on ReactionReactorDto {
  ReactionReactor toDomain() =>
      ReactionReactor(uid: uid, name: name, avatarUrl: avatarUrl);
}

extension ReactionSummaryDtoMapper on ReactionSummaryDto {
  ReactionSummary toDomain() => ReactionSummary(
    emoji: emoji,
    count: count,
    reactedByMe: reactedByMe,
    reactors: reactors?.map((reactor) => reactor.toDomain()).toList(),
  );
}

extension UserGroupInfoDtoMapper on UserGroupInfoDto {
  UserGroupInfo toDomain() => UserGroupInfo(
    groupId: groupId,
    name: name,
    chatGroupColor: chatGroupColor,
    chatGroupColorDark: chatGroupColorDark,
  );
}

extension MentionInfoDtoMapper on MentionInfoDto {
  MentionInfo toDomain() => MentionInfo(
    uid: uid,
    username: username,
    avatarUrl: avatarUrl,
    gender: gender,
    userGroup: userGroup?.toDomain(),
  );
}

extension ReplyToMessageDtoMapper on ReplyToMessageDto {
  ReplyToMessage toDomain() => ReplyToMessage(
    id: id,
    message: message,
    messageType: messageType,
    sticker: sticker?.toDomain(),
    sender: sender.toDomain(),
    isDeleted: isDeleted,
    attachments: attachments
        .map((attachment) => attachment.toDomain())
        .toList(),
    firstAttachmentKind: firstAttachmentKind,
    mentions: mentions.map((mention) => mention.toDomain()).toList(),
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
    sticker: sticker?.toDomain(),
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
    reactions: reactions.map((reaction) => reaction.toDomain()).toList(),
    mentions: mentions.map((mention) => mention.toDomain()).toList(),
    threadInfo: threadInfo?.toDomain(),
  );

  ConversationMessage toConversation(ConversationScope scope) =>
      ConversationMessage(
        scope: scope,
        serverMessageId: id,
        clientGeneratedId: clientGeneratedId,
        sender: sender.toDomain(),
        message: message,
        messageType: messageType,
        sticker: sticker?.toDomain(),
        createdAt: createdAt,
        isEdited: isEdited,
        isDeleted: isDeleted,
        replyRootId: replyRootId,
        hasAttachments: hasAttachments,
        replyToMessage: replyToMessage?.toDomain(),
        attachments: attachments
            .map((attachment) => attachment.toDomain())
            .toList(),
        reactions: reactions.map((reaction) => reaction.toDomain()).toList(),
        mentions: mentions.map((mention) => mention.toDomain()).toList(),
        threadInfo: threadInfo?.toDomain(),
      );
}
