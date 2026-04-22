import 'package:chahua/core/api/models/messages_api_models.dart';
import 'package:chahua/core/api/models/websocket_api_models.dart';
import 'package:chahua/features/conversation/shared/data/conversation_canonical_message_store.dart';
import 'package:chahua/features/conversation/shared/domain/conversation_message_v2.dart';
import 'package:chahua/features/conversation/shared/domain/conversation_identity.dart';
import 'package:chahua/features/chats/models/message_api_mapper.dart';
import 'package:chahua/features/chats/models/message_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConversationTimelineV2RealtimeApplier {
  ConversationTimelineV2RealtimeApplier(this.ref);

  final Ref ref;

  void apply(ApiWsEvent event) {
    switch (event) {
      case MessageCreatedWsEvent(:final payload):
        _newMessage(payload);
        return;
      case MessageUpdatedWsEvent(:final payload):
        _updateMessage(payload);
        return;
      case MessageDeletedWsEvent(:final payload):
        _deleteMessage(payload);
        return;
      case ReactionUpdatedWsEvent(:final payload):
        _updateReaction(payload);
        return;
      case ThreadUpdatedWsEvent():
      case StickerPackOrderUpdatedWsEvent():
      case PongWsEvent():
        return;
    }
  }

  void _newMessage(MessageItemDto payload) {
    final scopes = ref.read(conversationTimelineV2MessageStoreProvider);
    final message = ConversationMessageV2.fromMessageItemDto(payload);

    for (final entry in scopes.entries) {
      final identity = entry.key;
      final scope = entry.value;

      if (!_matchesMessagePayload(identity, payload)) {
        continue;
      }
      if (!scope.hasLatestSegment) {
        continue;
      }

      final latestTail = scope.segments.isEmpty ? null : scope.segments.last;
      if (latestTail != null && payload.id <= latestTail.lastServerMessageId) {
        continue;
      }

      ref
          .read(conversationTimelineV2MessageStoreProvider.notifier)
          .newMessage(identity, message);
    }
  }

  void _updateMessage(MessageItemDto payload) {
    final scopes = ref.read(conversationTimelineV2MessageStoreProvider);
    final message = ConversationMessageV2.fromMessageItemDto(payload);

    for (final entry in scopes.entries) {
      final identity = entry.key;

      if (!_matchesMessagePayload(identity, payload)) {
        continue;
      }

      ref
          .read(conversationTimelineV2MessageStoreProvider.notifier)
          .updateMessage(identity, message);
    }
  }

  void _deleteMessage(MessageItemDto payload) {
    final scopes = ref.read(conversationTimelineV2MessageStoreProvider);

    for (final entry in scopes.entries) {
      final identity = entry.key;

      if (!_matchesMessagePayload(identity, payload)) {
        continue;
      }

      ref
          .read(conversationTimelineV2MessageStoreProvider.notifier)
          .deleteMessage(identity, payload.id);
    }
  }

  void _updateReaction(ReactionUpdatePayloadDto payload) {
    final scopes = ref.read(conversationTimelineV2MessageStoreProvider);
    final store = ref.read(conversationTimelineV2MessageStoreProvider.notifier);
    final nextReactions = payload.reactions
        .map((reaction) => reaction.toDomain())
        .toList(growable: false);

    for (final entry in scopes.entries) {
      final identity = entry.key;
      if (identity.chatId != payload.chatId) {
        continue;
      }

      final message = store.messageForServerMessageId(
        identity,
        payload.messageId,
      );
      if (message == null) {
        continue;
      }

      store.updateMessage(
        identity,
        message.copyWith(
          reactions: _mergeReactions(message.reactions, nextReactions),
        ),
      );
    }
  }

  List<ReactionSummary> _mergeReactions(
    List<ReactionSummary>? previous,
    List<ReactionSummary> incoming,
  ) {
    if (incoming.isEmpty) {
      return const <ReactionSummary>[];
    }

    final previousByEmoji = <String, ReactionSummary>{
      for (final reaction in previous ?? const <ReactionSummary>[])
        reaction.emoji: reaction,
    };
    return incoming
        .map((reaction) {
          final prior = previousByEmoji[reaction.emoji];
          return ReactionSummary(
            emoji: reaction.emoji,
            count: reaction.count,
            reactedByMe: reaction.reactedByMe ?? prior?.reactedByMe,
            reactors: reaction.reactors ?? prior?.reactors,
          );
        })
        .toList(growable: false);
  }

  bool _matchesMessagePayload(
    ConversationIdentity identity,
    MessageItemDto payload,
  ) {
    return payload.chatId == identity.chatId &&
        payload.replyRootId == identity.threadRootId;
  }
}

final conversationTimelineV2RealtimeApplierProvider =
    Provider<ConversationTimelineV2RealtimeApplier>(
      (ref) => ConversationTimelineV2RealtimeApplier(ref),
    );
