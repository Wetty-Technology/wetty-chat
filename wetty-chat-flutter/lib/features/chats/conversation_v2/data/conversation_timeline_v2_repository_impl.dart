import 'package:chahua/features/chats/conversation/data/message_api_service.dart';
import 'package:chahua/features/chats/conversation/domain/conversation_scope.dart';
import 'package:chahua/features/chats/conversation_v2/application/conversation_timeline_v2_message_store.dart';
import 'package:chahua/features/chats/conversation_v2/domain/conversation_message_v2.dart';
import 'package:chahua/features/chats/conversation_v2/domain/conversation_timeline_v2_canonical_scope.dart';
import 'package:chahua/features/chats/conversation_v2/domain/conversation_timeline_v2_identity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'conversation_timeline_v2_repository.dart';
import 'fake_conversation_timeline_v2_repository.dart';

class ConversationTimelineV2RepositoryImpl
    implements ConversationTimelineV2Repository {
  ConversationTimelineV2RepositoryImpl(this.ref, this.identity)
    : _fallback = FakeConversationTimelineV2Repository(ref, identity);

  final Ref ref;
  final ConversationTimelineV2Identity identity;
  final FakeConversationTimelineV2Repository _fallback;

  ConversationScope get _scope => identity.threadRootId == null
      ? ConversationScope.chat(chatId: identity.chatId)
      : ConversationScope.thread(
          chatId: identity.chatId,
          threadRootId: identity.threadRootId!,
        );

  @override
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

    if (response.messages.isEmpty) {
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

  @override
  Future<void> loadOlderBeforeAnchor(
    int anchorServerMessageId, {
    required int limit,
  }) {
    return _fallback.loadOlderBeforeAnchor(anchorServerMessageId, limit: limit);
  }

  @override
  Future<void> loadNewerAfterAnchor(
    int anchorServerMessageId, {
    required int limit,
  }) {
    return _fallback.loadNewerAfterAnchor(anchorServerMessageId, limit: limit);
  }

  @override
  Future<void> refreshAroundServerMessageId(
    int targetServerMessageId, {
    required int limit,
  }) {
    return _fallback.refreshAroundServerMessageId(
      targetServerMessageId,
      limit: limit,
    );
  }

  @override
  Future<void> addLatestFakeMessage() {
    return _fallback.addLatestFakeMessage();
  }
}

final conversationTimelineV2RepositoryProvider =
    Provider.family<
      ConversationTimelineV2Repository,
      ConversationTimelineV2Identity
    >((ref, identity) => ConversationTimelineV2RepositoryImpl(ref, identity));
