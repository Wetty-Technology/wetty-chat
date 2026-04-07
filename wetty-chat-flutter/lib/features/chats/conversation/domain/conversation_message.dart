import '../../models/message_models.dart';
import 'conversation_scope.dart';

enum ConversationDeliveryState { sending, sent, failed, editing, deleting }

class ConversationMessage {
  const ConversationMessage({
    required this.scope,
    this.serverMessageId,
    this.localMessageId,
    required this.clientGeneratedId,
    required this.sender,
    required this.message,
    required this.messageType,
    this.sticker,
    required this.createdAt,
    required this.isEdited,
    required this.isDeleted,
    required this.replyRootId,
    required this.hasAttachments,
    required this.replyToMessage,
    required this.attachments,
    required this.reactions,
    required this.mentions,
    required this.threadInfo,
    this.deliveryState = ConversationDeliveryState.sent,
  });

  final ConversationScope scope;
  final int? serverMessageId;
  final String? localMessageId;
  final String clientGeneratedId;
  final Sender sender;
  final String? message;
  final String messageType;
  final StickerSummary? sticker;
  final DateTime? createdAt;
  final bool isEdited;
  final bool isDeleted;
  final int? replyRootId;
  final bool hasAttachments;
  final ReplyToMessage? replyToMessage;
  final List<AttachmentItem> attachments;
  final List<ReactionSummary> reactions;
  final List<MentionInfo> mentions;
  final ThreadInfo? threadInfo;
  final ConversationDeliveryState deliveryState;

  String get stableKey => serverMessageId != null
      ? 'server:$serverMessageId'
      : 'local:$localMessageId';

  bool get isLocalOnly => serverMessageId == null;
  bool get isPending => deliveryState == ConversationDeliveryState.sending;
  bool get isFailed => deliveryState == ConversationDeliveryState.failed;
  bool get isMutating =>
      deliveryState == ConversationDeliveryState.editing ||
      deliveryState == ConversationDeliveryState.deleting;

  ConversationMessage copyWith({
    ConversationScope? scope,
    Object? serverMessageId = _sentinel,
    Object? localMessageId = _sentinel,
    String? clientGeneratedId,
    Sender? sender,
    Object? message = _sentinel,
    String? messageType,
    Object? sticker = _sentinel,
    Object? createdAt = _sentinel,
    bool? isEdited,
    bool? isDeleted,
    Object? replyRootId = _sentinel,
    bool? hasAttachments,
    Object? replyToMessage = _sentinel,
    List<AttachmentItem>? attachments,
    List<ReactionSummary>? reactions,
    List<MentionInfo>? mentions,
    Object? threadInfo = _sentinel,
    ConversationDeliveryState? deliveryState,
  }) {
    return ConversationMessage(
      scope: scope ?? this.scope,
      serverMessageId: serverMessageId == _sentinel
          ? this.serverMessageId
          : serverMessageId as int?,
      localMessageId: localMessageId == _sentinel
          ? this.localMessageId
          : localMessageId as String?,
      clientGeneratedId: clientGeneratedId ?? this.clientGeneratedId,
      sender: sender ?? this.sender,
      message: message == _sentinel ? this.message : message as String?,
      messageType: messageType ?? this.messageType,
      sticker: sticker == _sentinel ? this.sticker : sticker as StickerSummary?,
      createdAt: createdAt == _sentinel
          ? this.createdAt
          : createdAt as DateTime?,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
      replyRootId: replyRootId == _sentinel
          ? this.replyRootId
          : replyRootId as int?,
      hasAttachments: hasAttachments ?? this.hasAttachments,
      replyToMessage: replyToMessage == _sentinel
          ? this.replyToMessage
          : replyToMessage as ReplyToMessage?,
      attachments: attachments ?? this.attachments,
      reactions: reactions ?? this.reactions,
      mentions: mentions ?? this.mentions,
      threadInfo: threadInfo == _sentinel
          ? this.threadInfo
          : threadInfo as ThreadInfo?,
      deliveryState: deliveryState ?? this.deliveryState,
    );
  }
}

const _sentinel = Object();
