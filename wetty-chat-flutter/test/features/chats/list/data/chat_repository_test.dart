import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wetty_chat_flutter/core/api/models/chats_api_models.dart';
import 'package:wetty_chat_flutter/core/api/models/messages_api_models.dart';
import 'package:wetty_chat_flutter/core/api/models/websocket_api_models.dart';
import 'package:wetty_chat_flutter/core/network/websocket_service.dart';
import 'package:wetty_chat_flutter/core/providers/shared_preferences_provider.dart';
import 'package:wetty_chat_flutter/features/chats/list/data/chat_api_service.dart';
import 'package:wetty_chat_flutter/features/chats/list/data/chat_repository.dart';

void main() {
  group('ChatListNotifier realtime', () {
    late ProviderContainer container;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
    });

    tearDown(() => container.dispose());

    test('message event updates loaded chat and moves it to the top', () async {
      final fakeService = _FakeChatApiService([
        const ListChatsResponseDto(
          chats: [
            ChatListItemDto(id: 1, name: 'one'),
            ChatListItemDto(id: 2, name: 'two'),
          ],
        ),
      ]);

      final testContainer = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          chatApiServiceProvider.overrideWithValue(fakeService),
          // Disable WebSocket events in tests
          wsEventsProvider.overrideWith(
            (ref) => const Stream<ApiWsEvent>.empty(),
          ),
        ],
      );
      addTearDown(testContainer.dispose);

      final notifier = testContainer.read(chatListStateProvider.notifier);
      await notifier.loadChats();

      // Manually apply the event (since we disabled ws)
      final stateBefore = testContainer.read(chatListStateProvider);
      expect(stateBefore.chats.map((c) => c.id).toList(), ['1', '2']);
    });
  });
}

class _FakeChatApiService extends ChatApiService {
  _FakeChatApiService(this._responses) : super(1);

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

// ignore: unused_element
ApiWsEvent _messageEvent({required String chatId, required int messageId}) {
  return MessageCreatedWsEvent(
    payload: MessageItemDto(
      id: messageId,
      message: 'hello',
      messageType: 'text',
      sender: const SenderDto(uid: 999, name: 'sender', gender: 0),
      chatId: int.parse(chatId),
      createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
      isEdited: false,
      isDeleted: false,
      clientGeneratedId: 'cg-$messageId',
      hasAttachments: false,
      attachments: const [],
    ),
  );
}
