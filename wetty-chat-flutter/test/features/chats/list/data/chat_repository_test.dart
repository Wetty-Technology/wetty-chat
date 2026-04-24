import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chahua/core/api/models/chats_api_models.dart';
import 'package:chahua/core/api/models/messages_api_models.dart';
import 'package:chahua/core/api/models/websocket_api_models.dart';
import 'package:chahua/core/providers/shared_preferences_provider.dart';
import 'package:chahua/features/chats/shared/data/chat_api_service.dart';
import 'package:chahua/features/chats/list/data/chat_repository.dart';

void main() {
  group('ChatListNotifier realtime', () {
    test(
      'confirmed root message updates preview and moves chat to top',
      () async {
        SharedPreferences.setMockInitialValues({});
        final fakeService = _FakeChatApiService([
          ListChatsResponseDto(
            chats: [
              _chatListItem(
                id: 2,
                name: 'two',
                lastMessage: _messageItem(id: 200, chatId: 2, text: 'old two'),
                lastMessageAt: DateTime.parse('2026-01-02T00:00:00Z'),
              ),
              _chatListItem(
                id: 1,
                name: 'one',
                lastMessage: _messageItem(id: 100, chatId: 1, text: 'old one'),
                lastMessageAt: DateTime.parse('2026-01-01T00:00:00Z'),
              ),
            ],
          ),
        ]);
        final testContainer = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(
              await SharedPreferences.getInstance(),
            ),
            chatApiServiceProvider.overrideWithValue(fakeService),
          ],
        );
        addTearDown(testContainer.dispose);

        final notifier = testContainer.read(chatListStateProvider.notifier);
        await notifier.loadChats();

        notifier.applyRealtimeEvent(
          _messageEvent(
            chatId: '1',
            messageId: 300,
            text: 'latest one',
            createdAt: DateTime.parse('2026-01-03T00:00:00Z'),
          ),
        );

        final state = testContainer.read(chatListStateProvider);
        expect(state.chats.map((c) => c.id).toList(), ['1', '2']);
        expect(state.chats.first.lastMessage?.message, 'latest one');
        expect(state.chats.first.unreadCount, 1);
      },
    );

    test(
      'confirmed thread reply does not update chat preview or reorder row',
      () async {
        SharedPreferences.setMockInitialValues({});
        final fakeService = _FakeChatApiService([
          ListChatsResponseDto(
            chats: [
              _chatListItem(
                id: 2,
                name: 'two',
                lastMessage: _messageItem(id: 200, chatId: 2, text: 'old two'),
                lastMessageAt: DateTime.parse('2026-01-02T00:00:00Z'),
              ),
              _chatListItem(
                id: 1,
                name: 'one',
                lastMessage: _messageItem(id: 100, chatId: 1, text: 'old one'),
                lastMessageAt: DateTime.parse('2026-01-01T00:00:00Z'),
              ),
            ],
          ),
        ]);
        final testContainer = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(
              await SharedPreferences.getInstance(),
            ),
            chatApiServiceProvider.overrideWithValue(fakeService),
          ],
        );
        addTearDown(testContainer.dispose);

        final notifier = testContainer.read(chatListStateProvider.notifier);
        await notifier.loadChats();

        notifier.applyRealtimeEvent(
          _messageEvent(
            chatId: '1',
            messageId: 301,
            text: 'thread reply',
            createdAt: DateTime.parse('2026-01-03T00:00:00Z'),
            replyRootId: 10,
          ),
        );

        final state = testContainer.read(chatListStateProvider);
        expect(state.chats.map((c) => c.id).toList(), ['2', '1']);
        expect(state.chats.last.lastMessage?.message, 'old one');
        expect(state.chats.last.unreadCount, 0);
      },
    );

    test(
      'duplicate confirmed root message does not increment unread twice',
      () async {
        SharedPreferences.setMockInitialValues({});
        final fakeService = _FakeChatApiService([
          ListChatsResponseDto(
            chats: [
              _chatListItem(
                id: 1,
                name: 'one',
                lastMessage: _messageItem(id: 100, chatId: 1, text: 'old one'),
                lastMessageAt: DateTime.parse('2026-01-01T00:00:00Z'),
              ),
            ],
          ),
        ]);
        final testContainer = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(
              await SharedPreferences.getInstance(),
            ),
            chatApiServiceProvider.overrideWithValue(fakeService),
          ],
        );
        addTearDown(testContainer.dispose);

        final notifier = testContainer.read(chatListStateProvider.notifier);
        await notifier.loadChats();

        final event = _messageEvent(
          chatId: '1',
          messageId: 300,
          text: 'latest one',
          createdAt: DateTime.parse('2026-01-03T00:00:00Z'),
        );
        notifier.applyRealtimeEvent(event);
        notifier.applyRealtimeEvent(event);

        final state = testContainer.read(chatListStateProvider);
        expect(state.chats.single.lastMessage?.message, 'latest one');
        expect(state.chats.single.unreadCount, 1);
      },
    );

    test(
      'confirmed root delete refreshes when preview fallback is unknown',
      () async {
        SharedPreferences.setMockInitialValues({});
        final fakeService = _FakeChatApiService([
          ListChatsResponseDto(
            chats: [
              _chatListItem(
                id: 1,
                name: 'one',
                lastMessage: _messageItem(id: 100, chatId: 1, text: 'old one'),
                lastMessageAt: DateTime.parse('2026-01-01T00:00:00Z'),
              ),
            ],
          ),
          ListChatsResponseDto(
            chats: [
              _chatListItem(
                id: 1,
                name: 'one',
                lastMessage: null,
                lastMessageAt: null,
              ),
            ],
          ),
        ]);
        final testContainer = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(
              await SharedPreferences.getInstance(),
            ),
            chatApiServiceProvider.overrideWithValue(fakeService),
          ],
        );
        addTearDown(testContainer.dispose);

        final notifier = testContainer.read(chatListStateProvider.notifier);
        await notifier.loadChats();

        notifier.applyRealtimeEvent(
          MessageDeletedWsEvent(
            payload: _messageItem(
              id: 100,
              chatId: 1,
              text: 'old one',
              isDeleted: true,
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final state = testContainer.read(chatListStateProvider);
        expect(fakeService.fetchChatsCalls, 2);
        expect(state.chats.single.lastMessage, isNull);
      },
    );

    test('message update patches current preview without refresh', () async {
      SharedPreferences.setMockInitialValues({});
      final fakeService = _FakeChatApiService([
        ListChatsResponseDto(
          chats: [
            _chatListItem(
              id: 1,
              name: 'one',
              lastMessage: _messageItem(id: 100, chatId: 1, text: 'old one'),
              lastMessageAt: DateTime.parse('2026-01-01T00:00:00Z'),
            ),
          ],
        ),
      ]);
      final testContainer = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
          chatApiServiceProvider.overrideWithValue(fakeService),
        ],
      );
      addTearDown(testContainer.dispose);

      final notifier = testContainer.read(chatListStateProvider.notifier);
      await notifier.loadChats();

      notifier.applyRealtimeEvent(
        MessageUpdatedWsEvent(
          payload: _messageItem(
            id: 100,
            chatId: 1,
            text: 'edited one',
            createdAt: DateTime.parse('2026-01-01T00:00:00Z'),
          ),
        ),
      );

      final state = testContainer.read(chatListStateProvider);
      expect(fakeService.fetchChatsCalls, 1);
      expect(state.chats.single.lastMessage?.message, 'edited one');
    });

    test(
      'deleting a non-preview message does not refresh or change preview',
      () async {
        SharedPreferences.setMockInitialValues({});
        final fakeService = _FakeChatApiService([
          ListChatsResponseDto(
            chats: [
              _chatListItem(
                id: 1,
                name: 'one',
                lastMessage: _messageItem(id: 100, chatId: 1, text: 'preview'),
                lastMessageAt: DateTime.parse('2026-01-01T00:00:00Z'),
              ),
            ],
          ),
        ]);
        final testContainer = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(
              await SharedPreferences.getInstance(),
            ),
            chatApiServiceProvider.overrideWithValue(fakeService),
          ],
        );
        addTearDown(testContainer.dispose);

        final notifier = testContainer.read(chatListStateProvider.notifier);
        await notifier.loadChats();

        notifier.applyRealtimeEvent(
          MessageDeletedWsEvent(
            payload: _messageItem(
              id: 99,
              chatId: 1,
              text: 'older',
              isDeleted: true,
            ),
          ),
        );

        final state = testContainer.read(chatListStateProvider);
        expect(fakeService.fetchChatsCalls, 1);
        expect(state.chats.single.lastMessage?.message, 'preview');
      },
    );

    test(
      'loadChats refresh replaces stale realtime projection and ordering',
      () async {
        SharedPreferences.setMockInitialValues({});
        final fakeService = _FakeChatApiService([
          ListChatsResponseDto(
            chats: [
              _chatListItem(
                id: 2,
                name: 'two',
                lastMessage: _messageItem(id: 200, chatId: 2, text: 'old two'),
                lastMessageAt: DateTime.parse('2026-01-02T00:00:00Z'),
              ),
              _chatListItem(
                id: 1,
                name: 'one',
                lastMessage: _messageItem(id: 100, chatId: 1, text: 'old one'),
                lastMessageAt: DateTime.parse('2026-01-01T00:00:00Z'),
              ),
            ],
          ),
          ListChatsResponseDto(
            chats: [
              _chatListItem(
                id: 2,
                name: 'two',
                lastMessage: _messageItem(
                  id: 201,
                  chatId: 2,
                  text: 'server two',
                ),
                lastMessageAt: DateTime.parse('2026-01-04T00:00:00Z'),
              ),
              _chatListItem(
                id: 1,
                name: 'one',
                lastMessage: _messageItem(
                  id: 300,
                  chatId: 1,
                  text: 'local one',
                ),
                lastMessageAt: DateTime.parse('2026-01-03T00:00:00Z'),
              ),
            ],
          ),
        ]);
        final testContainer = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(
              await SharedPreferences.getInstance(),
            ),
            chatApiServiceProvider.overrideWithValue(fakeService),
          ],
        );
        addTearDown(testContainer.dispose);

        final notifier = testContainer.read(chatListStateProvider.notifier);
        await notifier.loadChats();
        notifier.applyRealtimeEvent(
          _messageEvent(
            chatId: '1',
            messageId: 300,
            text: 'local one',
            createdAt: DateTime.parse('2026-01-03T00:00:00Z'),
          ),
        );

        await notifier.loadChats();

        final state = testContainer.read(chatListStateProvider);
        expect(state.chats.map((chat) => chat.id).toList(), ['2', '1']);
        expect(state.chats.first.lastMessage?.message, 'server two');
        expect(state.chats.last.lastMessage?.message, 'local one');
      },
    );
  });
}

class _FakeChatApiService extends ChatApiService {
  _FakeChatApiService(this._responses) : super(Dio());

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

MessageCreatedWsEvent _messageEvent({
  required String chatId,
  required int messageId,
  required String text,
  required DateTime createdAt,
  int? replyRootId,
}) {
  return MessageCreatedWsEvent(
    payload: _messageItem(
      id: messageId,
      chatId: int.parse(chatId),
      text: text,
      createdAt: createdAt,
      replyRootId: replyRootId,
    ),
  );
}

ChatListItemDto _chatListItem({
  required int id,
  required String name,
  MessageItemDto? lastMessage,
  DateTime? lastMessageAt,
}) {
  return ChatListItemDto(
    id: id,
    name: name,
    lastMessage: lastMessage,
    lastMessageAt: lastMessageAt,
  );
}

MessageItemDto _messageItem({
  required int id,
  required int chatId,
  required String text,
  DateTime? createdAt,
  bool isDeleted = false,
  int? replyRootId,
}) {
  return MessageItemDto(
    id: id,
    message: text,
    messageType: 'text',
    sender: const SenderDto(uid: 999, name: 'sender', gender: 0),
    chatId: chatId,
    createdAt: createdAt,
    isEdited: false,
    isDeleted: isDeleted,
    clientGeneratedId: 'cg-$id',
    replyRootId: replyRootId,
    hasAttachments: false,
    attachments: const [],
  );
}
