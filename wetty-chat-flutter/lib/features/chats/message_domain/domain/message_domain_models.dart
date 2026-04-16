import '../../conversation/domain/conversation_message.dart';
import '../../conversation/domain/conversation_scope.dart';
import '../../models/message_models.dart';

/// Draft payload used to create an optimistic message inside the domain store.
class MessageDomainDraftMessage {
  const MessageDomainDraftMessage({
    required this.scope,
    required this.clientGeneratedId,
    required this.sender,
    this.message,
    this.messageType = 'text',
    this.sticker,
    this.createdAt,
    this.replyToMessage,
    this.attachments = const <AttachmentItem>[],
    this.reactions = const <ReactionSummary>[],
    this.mentions = const <MentionInfo>[],
  });

  final ConversationScope scope;
  final String clientGeneratedId;
  final Sender sender;
  final String? message;
  final String messageType;
  final StickerSummary? sticker;
  final DateTime? createdAt;
  final ReplyToMessage? replyToMessage;
  final List<AttachmentItem> attachments;
  final List<ReactionSummary> reactions;
  final List<MentionInfo> mentions;
}

/// Thread summary projected onto a normal message that acts as a thread anchor.
class MessageThreadAnchorState {
  const MessageThreadAnchorState({required this.replyCount, this.lastReplyAt});

  final int replyCount;
  final DateTime? lastReplyAt;

  MessageThreadAnchorState copyWith({int? replyCount, DateTime? lastReplyAt}) {
    return MessageThreadAnchorState(
      replyCount: replyCount ?? this.replyCount,
      lastReplyAt: lastReplyAt ?? this.lastReplyAt,
    );
  }
}

enum MessageWindowPageDirection { older, newer }

enum MessageRangeKind { latest, active }

class MessageRangeState {
  const MessageRangeState({
    required this.kind,
    required this.stableKeys,
    this.anchorMessageId,
    this.hasReachedOldest = false,
    this.hasReachedNewest = false,
  });

  final MessageRangeKind kind;
  final List<String> stableKeys;
  final int? anchorMessageId;
  final bool hasReachedOldest;
  final bool hasReachedNewest;

  int? get minServerId => _rangeBound(first: true);
  int? get maxServerId => _rangeBound(first: false);

  MessageRangeState copyWith({
    MessageRangeKind? kind,
    List<String>? stableKeys,
    Object? anchorMessageId = _messageRangeSentinel,
    bool? hasReachedOldest,
    bool? hasReachedNewest,
  }) {
    return MessageRangeState(
      kind: kind ?? this.kind,
      stableKeys: stableKeys ?? this.stableKeys,
      anchorMessageId: anchorMessageId == _messageRangeSentinel
          ? this.anchorMessageId
          : anchorMessageId as int?,
      hasReachedOldest: hasReachedOldest ?? this.hasReachedOldest,
      hasReachedNewest: hasReachedNewest ?? this.hasReachedNewest,
    );
  }

  int? _rangeBound({required bool first}) {
    final ordered = stableKeys
        .where((key) => key.startsWith('server:'))
        .map((key) => int.tryParse(key.substring('server:'.length)))
        .whereType<int>()
        .toList(growable: false);
    if (ordered.isEmpty) {
      return null;
    }
    return first ? ordered.first : ordered.last;
  }
}

const _messageRangeSentinel = Object();

/// Helpers for normalizing domain messages from backend models.
abstract final class MessageDomainMessageFactory {
  static ConversationScope inferScope(MessageItem message) {
    final threadRootId = message.replyRootId;
    if (threadRootId != null) {
      return ConversationScope.thread(
        chatId: message.chatId,
        threadRootId: threadRootId.toString(),
      );
    }
    return ConversationScope.chat(chatId: message.chatId);
  }

  static ConversationMessage fromMessageItem(
    MessageItem message, {
    ConversationScope? scope,
    ConversationDeliveryState deliveryState =
        ConversationDeliveryState.confirmed,
  }) {
    final resolvedScope = scope ?? inferScope(message);
    return ConversationMessage(
      scope: resolvedScope,
      serverMessageId: message.id,
      clientGeneratedId: message.clientGeneratedId,
      sender: message.sender,
      message: message.message,
      messageType: message.messageType,
      sticker: message.sticker,
      createdAt: message.createdAt,
      isEdited: message.isEdited,
      isDeleted: message.isDeleted,
      replyRootId: message.replyRootId,
      hasAttachments: message.hasAttachments,
      replyToMessage: message.replyToMessage,
      attachments: message.attachments,
      reactions: message.reactions,
      mentions: message.mentions,
      threadInfo: message.threadInfo,
      deliveryState: deliveryState,
    );
  }
}
