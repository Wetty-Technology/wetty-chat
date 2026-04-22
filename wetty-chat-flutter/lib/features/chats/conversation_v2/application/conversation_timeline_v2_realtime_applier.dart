import 'package:chahua/core/api/models/messages_api_models.dart';
import 'package:chahua/core/api/models/websocket_api_models.dart';
import 'package:chahua/features/chats/conversation_v2/application/conversation_timeline_v2_message_store.dart';
import 'package:chahua/features/chats/conversation_v2/domain/conversation_message_v2.dart';
import 'package:chahua/features/chats/conversation_v2/domain/conversation_identity.dart';
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
      case ReactionUpdatedWsEvent():
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
