import 'package:freezed_annotation/freezed_annotation.dart';

import '../../conversation_v2/domain/conversation_message_v2.dart'
    show ConversationDeliveryState;
export '../../conversation_v2/domain/conversation_message_v2.dart'
    show ConversationDeliveryState;
import '../../models/message_models.dart';
import 'conversation_scope.dart';

part 'conversation_message.freezed.dart';

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

  bool get isSystem => messageType == 'system';
  bool get isLocalOnly => serverMessageId == null;
  bool get isPending => deliveryState == ConversationDeliveryState.sending;
  bool get isSent =>
      deliveryState == ConversationDeliveryState.sent ||
      deliveryState == ConversationDeliveryState.confirmed;
  bool get isConfirmed => deliveryState == ConversationDeliveryState.confirmed;
  bool get isFailed => deliveryState == ConversationDeliveryState.failed;
  bool get isMutating =>
      deliveryState == ConversationDeliveryState.editing ||
      deliveryState == ConversationDeliveryState.deleting;
}
