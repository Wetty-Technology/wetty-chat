import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../conversation/compose/data/message_api_service_v2.dart';
import '../../list/data/chat_api_service.dart';
import '../../threads/data/thread_api_service.dart';

typedef ChatReadStateUpdate = ({String? lastReadMessageId, int unreadCount});

typedef ThreadReadStateUpdate = ({bool updated});

class ReadStateRepository {
  ReadStateRepository(this.ref);

  final Ref ref;

  Future<ChatReadStateUpdate> markChatRead({
    required String chatId,
    required int messageId,
  }) async {
    final response = await ref
        .read(messageApiServiceV2Provider)
        .markMessagesAsRead(chatId, messageId);
    return (
      lastReadMessageId: response.lastReadMessageId,
      unreadCount: response.unreadCount,
    );
  }

  Future<ChatReadStateUpdate> markChatUnread({required String chatId}) async {
    final response = await ref
        .read(chatApiServiceProvider)
        .markChatAsUnread(chatId);
    return (
      lastReadMessageId: response.lastReadMessageId,
      unreadCount: response.unreadCount,
    );
  }

  Future<ThreadReadStateUpdate> markThreadRead({
    required int threadRootId,
    required int messageId,
  }) async {
    final response = await ref
        .read(threadApiServiceProvider)
        .markThreadAsRead(threadRootId, messageId);
    return (updated: response.updated);
  }
}

final readStateRepositoryProvider = Provider<ReadStateRepository>((ref) {
  return ReadStateRepository(ref);
});
