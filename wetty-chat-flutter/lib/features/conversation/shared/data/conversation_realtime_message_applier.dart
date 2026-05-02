import 'package:chahua/core/api/models/messages_api_models.dart';
import 'package:chahua/core/api/models/websocket_api_models.dart';
import 'package:chahua/features/conversation/pins/application/pinned_messages_provider.dart';
import 'package:chahua/features/conversation/shared/application/conversation_canonical_message_store.dart';
import 'package:chahua/features/shared/model/message/message.dart';
import 'package:chahua/features/conversation/shared/domain/conversation_identity.dart';
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
        _patchPins(payload);
        return;
      case MessageDeletedWsEvent(:final payload):
        _deleteMessage(payload);
        _patchPins(payload);
        return;
      case ReactionUpdatedWsEvent(:final payload):
        _updateReaction(payload);
        return;
      case ThreadUpdatedWsEvent():
      case PinAddedWsEvent():
      case PinRemovedWsEvent():
      case StickerPackOrderUpdatedWsEvent():
      case PongWsEvent():
        return;
    }
  }

  void _newMessage(MessageItemDto payload) {
    final scopes = ref.read(conversationTimelineMessageStoreProvider);
    final message = ConversationMessageV2.fromMessageItemDto(payload);

    for (final entry in scopes.entries) {
      final identity = entry.key;
      final scope = entry.value;

      if (!_matchesMessagePayload(identity, payload)) {
        continue;
      }
      if (!scope.hasReachedLatest) {
        continue;
      }

      final latestTail = scope.segments.isEmpty ? null : scope.segments.last;
      if (latestTail != null && payload.id <= latestTail.lastServerMessageId) {
        continue;
      }

      ref
          .read(conversationTimelineMessageStoreProvider.notifier)
          .newMessage(identity, message);
    }
  }

  void _updateMessage(MessageItemDto payload) {
    final scopes = ref.read(conversationTimelineMessageStoreProvider);
    final message = ConversationMessageV2.fromMessageItemDto(payload);

    for (final entry in scopes.entries) {
      final identity = entry.key;

      if (!_matchesMessagePayload(identity, payload)) {
        continue;
      }

      ref
          .read(conversationTimelineMessageStoreProvider.notifier)
          .updateMessage(identity, message);
    }
  }

  void _deleteMessage(MessageItemDto payload) {
    final scopes = ref.read(conversationTimelineMessageStoreProvider);

    for (final entry in scopes.entries) {
      final identity = entry.key;

      if (!_matchesMessagePayload(identity, payload)) {
        continue;
      }

      ref
          .read(conversationTimelineMessageStoreProvider.notifier)
          .deleteMessage(identity, payload.id);
    }
  }

  void _updateReaction(ReactionUpdatePayloadDto payload) {
    final scopes = ref.read(conversationTimelineMessageStoreProvider);
    final store = ref.read(conversationTimelineMessageStoreProvider.notifier);
    final nextReactions = payload.reactions
        .map(ReactionSummary.fromDto)
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

  void _patchPins(MessageItemDto payload) {
    final identity = (chatId: payload.chatId, threadRootId: null);
    if (!ref
        .read(conversationTimelineMessageStoreProvider)
        .containsKey(identity)) {
      return;
    }
    ref.read(pinnedMessagesProvider(identity).notifier).patchMessage(payload);
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
