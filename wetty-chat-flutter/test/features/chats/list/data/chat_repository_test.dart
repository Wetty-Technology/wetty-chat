import 'package:flutter_test/flutter_test.dart';

import 'package:wetty_chat_flutter/core/api/models/chats_api_models.dart';
import 'package:wetty_chat_flutter/core/api/models/messages_api_models.dart';
import 'package:wetty_chat_flutter/core/api/models/websocket_api_models.dart';
import 'package:wetty_chat_flutter/features/chats/list/data/chat_api_service.dart';
import 'package:wetty_chat_flutter/features/chats/list/data/chat_repository.dart';

void main() {
  group('ChatRepository realtime', () {
    test('message event updates loaded chat and moves it to the top', () async {
      final repository = ChatRepository(
        service: _FakeChatApiService([
          const ListChatsResponseDto(
            chats: [
              ChatListItemDto(id: 1, name: 'one'),
              ChatListItemDto(id: 2, name: 'two'),
            ],
          ),
        ]),
      );

      await repository.loadChats();
      repository.applyRealtimeEvent(_messageEvent(chatId: '2', messageId: 200));

      expect(repository.chats.map((chat) => chat.id).toList(), ['2', '1']);
      expect(repository.chats.first.lastMessage?.id, 200);
      expect(repository.chats.first.unreadCount, 1);
    });

    test(
      'message event refreshes when chat is not in the loaded page',
      () async {
        final service = _FakeChatApiService([
          const ListChatsResponseDto(
            chats: [ChatListItemDto(id: 1, name: 'one')],
          ),
          const ListChatsResponseDto(
            chats: [
              ChatListItemDto(id: 2, name: 'two'),
              ChatListItemDto(id: 1, name: 'one'),
            ],
          ),
        ]);
        final repository = ChatRepository(service: service);

        await repository.loadChats();
        repository.applyRealtimeEvent(
          _messageEvent(chatId: '2', messageId: 200),
        );
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(service.fetchChatsCalls, 2);
        expect(repository.chats.map((chat) => chat.id).toList(), ['2', '1']);
      },
    );
  });
}

class _FakeChatApiService extends ChatApiService {
  _FakeChatApiService(this._responses);

  final List<ListChatsResponseDto> _responses;
  int fetchChatsCalls = 0;

  @override
  Future<ListChatsResponseDto> fetchChats({int? limit, String? after}) async {
    final index = fetchChatsCalls < _responses.length
        ? fetchChatsCalls
        : _responses.length - 1;
    fetchChatsCalls++;
    return _responses[index];
  }
}

ApiWsEvent _messageEvent({required String chatId, required int messageId}) {
  return MessageCreatedWsEvent(
    payload: MessageItemDto(
      id: messageId,
      message: 'hello',
      messageType: 'text',
      sender: const SenderDto(uid: 999, name: 'sender', gender: 0),
      chatId: int.parse(chatId),
      createdAt: '2026-01-01T00:00:00Z',
      isEdited: false,
      isDeleted: false,
      clientGeneratedId: 'cg-$messageId',
      hasAttachments: false,
      attachments: const [],
    ),
  );
}
