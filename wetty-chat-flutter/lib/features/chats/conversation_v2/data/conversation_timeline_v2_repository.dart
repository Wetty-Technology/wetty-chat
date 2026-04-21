import 'package:chahua/features/chats/conversation/data/message_api_service.dart';
import 'package:chahua/features/chats/conversation/domain/conversation_scope.dart';
import 'package:chahua/features/chats/conversation_v2/application/conversation_timeline_v2_message_store.dart';
import 'package:chahua/features/chats/conversation_v2/domain/conversation_message_v2.dart';
import 'package:chahua/features/chats/conversation_v2/domain/conversation_timeline_v2_canonical_scope.dart';
import 'package:chahua/features/chats/conversation_v2/domain/conversation_timeline_v2_identity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConversationTimelineV2Repository {
  ConversationTimelineV2Repository(this.ref, this.identity);

  final Ref ref;
  final ConversationTimelineV2Identity identity;

  ConversationScope get _scope => identity.threadRootId == null
      ? ConversationScope.chat(chatId: identity.chatId)
      : ConversationScope.thread(
          chatId: identity.chatId,
          threadRootId: identity.threadRootId!,
        );

  ConversationTimelineV2MessageStore get _store =>
      ref.read(conversationTimelineV2MessageStoreProvider.notifier);

  Future<void> sendMessage({
    required ConversationMessageV2 optimisticMessage,
    // TODO(conversation_v2): remove this once transport can derive uploaded
    // attachment ids directly from the optimistic message payload.
    required List<String> attachmentIds,
  }) async {
    // Optimistically insert the message into the timeline.
    _store.newMessage(identity, optimisticMessage);

    // TODO(conversation_v2): catch POST failures here, mark the optimistic
    // row as failed in the v2 store, and keep the same clientGeneratedId for
    // later retry/discard actions.
    // Send the message to the server.
    await ref
        .read(messageApiServiceProvider)
        .sendConversationMessage(
          _scope,
          _textFor(optimisticMessage),
          messageType: _messageTypeFor(optimisticMessage),
          replyToId: optimisticMessage.replyToMessage?.id,
          attachmentIds: attachmentIds,
          clientGeneratedId: optimisticMessage.clientGeneratedId,
          stickerId: _stickerIdFor(optimisticMessage),
        );
  }

  String _messageTypeFor(ConversationMessageV2 message) {
    return switch (message.content) {
      TextMessageContent() => 'text',
      AudioMessageContent() => 'audio',
      FileMessageContent() => 'text',
      StickerMessageContent() => 'sticker',
      InviteMessageContent() => 'invite',
      SystemMessageContent() => 'system',
    };
  }

  String _textFor(ConversationMessageV2 message) {
    return switch (message.content) {
      TextMessageContent(:final text) => text,
      AudioMessageContent(:final text) => text ?? '',
      FileMessageContent(:final text) => text ?? '',
      InviteMessageContent(:final text) => text ?? '',
      SystemMessageContent(:final text) => text,
      StickerMessageContent() => '',
    };
  }

  String? _stickerIdFor(ConversationMessageV2 message) {
    return switch (message.content) {
      StickerMessageContent(:final sticker) => sticker.id,
      _ => null,
    };
  }

  Future<void> refreshLatestSegment({required int limit}) async {
    final existingScope = ref.read(
      conversationTimelineV2MessageStoreProvider,
    )[identity];
    if (existingScope?.hasLatestSegment ?? false) {
      return;
    }

    final response = await ref
        .read(messageApiServiceProvider)
        .fetchConversationMessages(_scope, max: limit);

    // If the response is empty, means we are at latest but there is just simply no message
    if (response.messages.isEmpty) {
      ref
          .read(conversationTimelineV2MessageStoreProvider.notifier)
          .putScope(
            identity,
            const ConversationTimelineV2CanonicalScope(
              hasLatestSegment: true,
              hasReachedOldest: true,
            ),
          );
      return;
    }

    final latestSegment = ConversationTimelineV2CanonicalSegment(
      orderedMessages: response.messages
          .map(ConversationMessageV2.fromMessageItemDto)
          .toList(growable: false),
    );

    ref
        .read(conversationTimelineV2MessageStoreProvider.notifier)
        .insertLatest(identity, latestSegment);
  }

  Future<void> loadOlderBeforeAnchor(
    int anchorServerMessageId, {
    required int limit,
  }) {
    return _loadOlderBeforeAnchor(anchorServerMessageId, limit: limit);
  }

  Future<void> loadNewerAfterAnchor(
    int anchorServerMessageId, {
    required int limit,
  }) {
    return _loadNewerAfterAnchor(anchorServerMessageId, limit: limit);
  }

  Future<void> refreshAroundServerMessageId(
    int targetServerMessageId, {
    required int limit,
  }) {
    return _refreshAroundServerMessageId(targetServerMessageId, limit: limit);
  }

  Future<void> _loadOlderBeforeAnchor(
    int anchorServerMessageId, {
    required int limit,
  }) async {
    final response = await ref
        .read(messageApiServiceProvider)
        .fetchConversationMessages(
          _scope,
          before: anchorServerMessageId,
          max: limit,
        );

    if (response.messages.isEmpty) {
      ref
          .read(conversationTimelineV2MessageStoreProvider.notifier)
          .markReachedOldest(identity);
      return;
    }

    ref
        .read(conversationTimelineV2MessageStoreProvider.notifier)
        .insertBeforeAnchor(
          identity,
          anchorServerMessageId,
          ConversationTimelineV2CanonicalSegment(
            orderedMessages: response.messages
                .map(ConversationMessageV2.fromMessageItemDto)
                .toList(growable: false),
          ),
        );
  }

  Future<void> _loadNewerAfterAnchor(
    int anchorServerMessageId, {
    required int limit,
  }) async {
    final response = await ref
        .read(messageApiServiceProvider)
        .fetchConversationMessages(
          _scope,
          after: anchorServerMessageId,
          max: limit,
        );

    if (response.messages.isNotEmpty) {
      ref
          .read(conversationTimelineV2MessageStoreProvider.notifier)
          .insertAfterAnchor(
            identity,
            anchorServerMessageId,
            ConversationTimelineV2CanonicalSegment(
              orderedMessages: response.messages
                  .map(ConversationMessageV2.fromMessageItemDto)
                  .toList(growable: false),
            ),
          );
    }
  }

  Future<void> _refreshAroundServerMessageId(
    int targetServerMessageId, {
    required int limit,
  }) async {
    final response = await ref
        .read(messageApiServiceProvider)
        .fetchConversationMessages(
          _scope,
          around: targetServerMessageId,
          max: limit,
        );

    if (response.messages.isEmpty) {
      return;
    }

    final containsTarget = response.messages.any(
      (message) => message.id == targetServerMessageId,
    );
    if (!containsTarget) {
      return;
    }

    ref
        .read(conversationTimelineV2MessageStoreProvider.notifier)
        .insertAround(
          identity,
          ConversationTimelineV2CanonicalSegment(
            orderedMessages: response.messages
                .map(ConversationMessageV2.fromMessageItemDto)
                .toList(growable: false),
          ),
        );
  }
}

final conversationTimelineV2RepositoryProvider =
    Provider.family<
      ConversationTimelineV2Repository,
      ConversationTimelineV2Identity
    >((ref, identity) => ConversationTimelineV2Repository(ref, identity));
