import 'package:chahua/core/api/models/messages_api_models.dart';
import 'package:chahua/features/chats/conversation_v2/application/conversation_timeline_v2_message_store.dart';
import 'package:chahua/features/chats/conversation_v2/domain/conversation_message_v2.dart';
import 'package:chahua/features/chats/conversation_v2/domain/conversation_timeline_v2_identity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConversationTimelineV2RealtimeApplier {
  ConversationTimelineV2RealtimeApplier(this.ref);

  final Ref ref;

  void applyCreatedMessage(MessageItemDto payload) {
    final scopes = ref.read(conversationTimelineV2MessageStoreProvider);

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
          .insertLatestMessage(
            identity,
            ConversationMessageV2.fromMessageItemDto(payload),
          );
    }
  }

  bool _matchesMessagePayload(
    ConversationTimelineV2Identity identity,
    MessageItemDto payload,
  ) {
    if (payload.chatId.toString() != identity.chatId) {
      return false;
    }

    final threadRootId = identity.threadRootId;
    if (threadRootId == null) {
      return true;
    }

    return payload.id.toString() == threadRootId ||
        payload.replyRootId?.toString() == threadRootId;
  }
}

final conversationTimelineV2RealtimeApplierProvider =
    Provider<ConversationTimelineV2RealtimeApplier>(
      (ref) => ConversationTimelineV2RealtimeApplier(ref),
    );
