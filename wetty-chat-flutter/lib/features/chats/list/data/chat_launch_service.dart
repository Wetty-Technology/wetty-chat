import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../conversation/data/message_api_service.dart';
import '../../conversation/domain/conversation_scope.dart';
import '../../conversation/domain/launch_request.dart';
import '../../models/chat_models.dart';

class ChatLaunchService {
  ChatLaunchService({required MessageApiService messageApiService})
    : _messageApiService = messageApiService;

  final MessageApiService _messageApiService;

  Future<LaunchRequest> resolveLaunchRequest(ChatListItem chat) async {
    final lastReadMessageId = chat.lastReadMessageId;
    if (chat.unreadCount <= 0 || lastReadMessageId == null) {
      return const LaunchRequest.latest();
    }

    final parsedId = int.tryParse(lastReadMessageId);
    if (parsedId == null) {
      return const LaunchRequest.latest();
    }

    final response = await _messageApiService.fetchConversationMessages(
      ConversationScope.chat(chat.id),
      after: parsedId,
      max: 1,
    );
    final unreadMessageId = response.messages.firstOrNull?.id;
    if (unreadMessageId == null) {
      return const LaunchRequest.latest();
    }
    return LaunchRequest.unread(unreadMessageId);
  }
}

final chatLaunchServiceProvider = Provider<ChatLaunchService>((ref) {
  return ChatLaunchService(
    messageApiService: ref.read(messageApiServiceProvider),
  );
});
