import 'package:freezed_annotation/freezed_annotation.dart';

import '../../models/message_models.dart';
import 'conversation_scope.dart';

part 'conversation_message.freezed.dart';

enum ConversationDeliveryState { sending, sent, failed, editing, deleting }

@freezed
abstract class ConversationMessage with _$ConversationMessage {
  const ConversationMessage._();

  const factory ConversationMessage({
    required ConversationScope scope,
    int? serverMessageId,
    String? localMessageId,
    required String clientGeneratedId,
    required Sender sender,
    String? message,
    @Default('text') String messageType,
    StickerSummary? sticker,
    DateTime? createdAt,
    @Default(false) bool isEdited,
    @Default(false) bool isDeleted,
    int? replyRootId,
    @Default(false) bool hasAttachments,
    ReplyToMessage? replyToMessage,
    @Default([]) List<AttachmentItem> attachments,
    @Default([]) List<ReactionSummary> reactions,
    @Default([]) List<MentionInfo> mentions,
    ThreadInfo? threadInfo,
    @Default(ConversationDeliveryState.sent)
    ConversationDeliveryState deliveryState,
  }) = _ConversationMessage;

  String get stableKey => serverMessageId != null
      ? 'server:$serverMessageId'
      : 'local:$localMessageId';

  bool get isLocalOnly => serverMessageId == null;
  bool get isPending => deliveryState == ConversationDeliveryState.sending;
  bool get isFailed => deliveryState == ConversationDeliveryState.failed;
  bool get isMutating =>
      deliveryState == ConversationDeliveryState.editing ||
      deliveryState == ConversationDeliveryState.deleting;
}
