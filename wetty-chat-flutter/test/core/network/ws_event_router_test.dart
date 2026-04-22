import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chahua/core/api/models/chats_api_models.dart';
import 'package:chahua/core/api/models/messages_api_models.dart';
import 'package:chahua/core/api/models/websocket_api_models.dart';
import 'package:chahua/core/network/websocket_service.dart';
import 'package:chahua/core/network/ws_event_router.dart';
import 'package:chahua/core/notifications/apns_channel.dart';
import 'package:chahua/core/notifications/unread_badge_provider.dart';
import 'package:chahua/core/providers/shared_preferences_provider.dart';
import 'package:chahua/core/session/dev_session_store.dart';
import 'package:chahua/features/chats/conversation/application/conversation_realtime_registry.dart';
import 'package:chahua/features/chats/list/data/chat_api_service.dart';
import 'package:chahua/features/chats/list/data/chat_repository.dart';
import 'package:chahua/features/chats/threads/data/thread_api_service.dart';
import 'package:chahua/features/chats/threads/data/thread_repository.dart';
import 'package:chahua/features/chats/threads/models/thread_api_models.dart';
import 'package:chahua/features/stickers/data/sticker_pack_order_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('wsEventRouterProvider', () {
    test('thread update events fan out only to thread list', () async {
      final controller = StreamController<ApiWsEvent>.broadcast();
      final chatService = _FakeChatApiService(
        unreadCount: 0,
        chatResponses: [
          ListChatsResponseDto(
            chats: [
              _chatListItem(
                id: 2,
                name: 'two',
                lastMessage: _messageItem(id: 200, chatId: 2, text: 'chat two'),
                lastMessageAt: DateTime.parse('2026-01-02T00:00:00Z'),
              ),
              _chatListItem(
                id: 1,
                name: 'one',
                lastMessage: _messageItem(id: 100, chatId: 1, text: 'chat one'),
                lastMessageAt: DateTime.parse('2026-01-01T00:00:00Z'),
              ),
            ],
          ),
        ],
      );
      final threadService = _FakeThreadApiService(
        unreadCount: 0,
        threadResponses: [
          ListThreadsResponseDto(
            threads: [
              _threadItem(
                rootId: 20,
                chatId: 1,
                rootText: 'root two',
                lastReplyAt: DateTime.parse('2026-01-02T00:00:00Z'),
                replyCount: 1,
              ),
              _threadItem(
                rootId: 10,
                chatId: 1,
                rootText: 'root one',
                lastReplyAt: DateTime.parse('2026-01-01T00:00:00Z'),
                replyCount: 1,
              ),
            ],
          ),
          ListThreadsResponseDto(
            threads: [
              _threadItem(
                rootId: 10,
                chatId: 1,
                rootText: 'root one',
                lastReplyAt: DateTime.parse('2026-01-03T00:00:00Z'),
                replyCount: 4,
              ),
              _threadItem(
                rootId: 20,
                chatId: 1,
                rootText: 'root two',
                lastReplyAt: DateTime.parse('2026-01-02T00:00:00Z'),
                replyCount: 1,
              ),
            ],
          ),
        ],
      );
      final container = await _containerFor(
        controller: controller,
        chatService: chatService,
        threadService: threadService,
      );
      addTearDown(() async {
        await controller.close();
        container.dispose();
      });

      final routerSubscription = container.listen<void>(
        wsEventRouterProvider,
        (previous, next) {},
      );
      addTearDown(routerSubscription.close);
      await container.read(chatListStateProvider.notifier).loadChats();
      await container.read(threadListStateProvider.notifier).loadThreads();

      var conversationEvents = 0;
      final token = container
          .read(conversationRealtimeRegistryProvider)
          .addListener((_) => conversationEvents += 1);
      addTearDown(
        () => container
            .read(conversationRealtimeRegistryProvider)
            .removeListener(token),
      );

      controller.add(
        ThreadUpdatedWsEvent(
          payload: ThreadUpdatePayloadDto(
            threadRootId: 10,
            chatId: 1,
            lastReplyAt: DateTime.parse('2026-01-03T00:00:00Z'),
            replyCount: 4,
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 10));

      final chatState = container.read(chatListStateProvider);
      final threadState = container.read(threadListStateProvider);

      expect(conversationEvents, 0);
      expect(chatState.chats.map((chat) => chat.id).toList(), ['2', '1']);
      expect(
        threadState.threads.map((thread) => thread.threadRootId).toList(),
        [10, 20],
      );
      expect(threadState.threads.first.replyCount, 4);
      expect(threadService.fetchThreadsCalls, 2);
    });

    test('sticker pack order events only update sticker order store', () async {
      final controller = StreamController<ApiWsEvent>.broadcast();
      final container = await _containerFor(
        controller: controller,
        chatService: _FakeChatApiService(
          unreadCount: 0,
          chatResponses: const [],
        ),
        threadService: _FakeThreadApiService(
          unreadCount: 0,
          threadResponses: const [],
        ),
      );
      addTearDown(() async {
        await controller.close();
        container.dispose();
      });

      final routerSubscription = container.listen<void>(
        wsEventRouterProvider,
        (previous, next) {},
      );
      addTearDown(routerSubscription.close);

      controller.add(
        StickerPackOrderUpdatedWsEvent(
          payload: StickerPackOrderUpdatePayloadDto(
            order: const [
              StickerPackOrderItemDto(stickerPackId: 'pack-a', lastUsedOn: 123),
            ],
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final stickerState = container.read(stickerPackOrderProvider);
      final chatState = container.read(chatListStateProvider);
      final threadState = container.read(threadListStateProvider);

      expect(stickerState.packOrder, hasLength(1));
      expect(stickerState.packOrder.single.stickerPackId, 'pack-a');
      expect(chatState.chats, isEmpty);
      expect(threadState.threads, isEmpty);
    });
  });
}

Future<ProviderContainer> _containerFor({
  required StreamController<ApiWsEvent> controller,
  required _FakeChatApiService chatService,
  required _FakeThreadApiService threadService,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      authSessionProvider.overrideWith(_AuthenticatedSessionNotifier.new),
      sharedPreferencesProvider.overrideWithValue(prefs),
      chatApiServiceProvider.overrideWithValue(chatService),
      threadApiServiceProvider.overrideWithValue(threadService),
      apnsChannelProvider.overrideWithValue(_FakeApnsChannel()),
      webSocketProvider.overrideWithValue(
        _FakeWebSocketService(controller.stream),
      ),
    ],
  );
}

class _AuthenticatedSessionNotifier extends AuthSessionNotifier {
  @override
  AuthSessionState build() {
    return const AuthSessionState(
      status: AuthBootstrapStatus.authenticated,
      mode: AuthSessionMode.devHeader,
      developerUserId: 1,
      currentUserId: 1,
    );
  }
}

class _FakeChatApiService extends ChatApiService {
  _FakeChatApiService({required this.unreadCount, required this.chatResponses})
    : super(Dio());

  final int unreadCount;
  final List<ListChatsResponseDto> chatResponses;
  int fetchChatsCalls = 0;
  int fetchUnreadCountCalls = 0;

  @override
  Future<ListChatsResponseDto> fetchChats({int? limit, String? after}) async {
    final index = fetchChatsCalls < chatResponses.length
        ? fetchChatsCalls
        : chatResponses.length - 1;
    fetchChatsCalls += 1;
    return chatResponses[index];
  }

  @override
  Future<UnreadCountResponseDto> fetchUnreadCount() async {
    fetchUnreadCountCalls += 1;
    return UnreadCountResponseDto(unreadCount: unreadCount);
  }
}

class _FakeThreadApiService extends ThreadApiService {
  _FakeThreadApiService({
    required this.unreadCount,
    required this.threadResponses,
  }) : super(Dio());

  final int unreadCount;
  final List<ListThreadsResponseDto> threadResponses;
  int fetchThreadsCalls = 0;
  int fetchUnreadCountCalls = 0;

  @override
  Future<ListThreadsResponseDto> fetchThreads({
    int? limit,
    String? before,
  }) async {
    final index = fetchThreadsCalls < threadResponses.length
        ? fetchThreadsCalls
        : threadResponses.length - 1;
    fetchThreadsCalls += 1;
    return threadResponses[index];
  }

  @override
  Future<UnreadThreadCountResponseDto> fetchUnreadThreadCount() async {
    fetchUnreadCountCalls += 1;
    return UnreadThreadCountResponseDto(unreadThreadCount: unreadCount);
  }
}

class _FakeApnsChannel extends ApnsChannel {
  @override
  Future<void> clearBadge() async {}

  @override
  Future<void> setBadge(int count) async {}
}

class _FakeWebSocketService extends WebSocketService {
  _FakeWebSocketService(this._events) : super(Dio());

  final Stream<ApiWsEvent> _events;

  @override
  Stream<ApiWsEvent> get events => _events;

  @override
  Future<void> init() async {}

  @override
  void dispose() {}
}

ChatListItemDto _chatListItem({
  required int id,
  required String name,
  required MessageItemDto? lastMessage,
  required DateTime? lastMessageAt,
}) {
  return ChatListItemDto(
    id: id,
    name: name,
    unreadCount: 0,
    lastReadMessageId: null,
    lastMessage: lastMessage,
    lastMessageAt: lastMessageAt,
    mutedUntil: null,
  );
}

ThreadListItemDto _threadItem({
  required int rootId,
  required int chatId,
  required String rootText,
  required DateTime? lastReplyAt,
  int replyCount = 0,
}) {
  return ThreadListItemDto(
    chatId: chatId,
    chatName: 'chat $chatId',
    threadRootMessage: _messageItem(id: rootId, chatId: chatId, text: rootText),
    lastReply: null,
    replyCount: replyCount,
    lastReplyAt: lastReplyAt,
    subscribedAt: null,
  );
}

MessageItemDto _messageItem({
  required int id,
  required int chatId,
  required String text,
  DateTime? createdAt,
  int? replyRootId,
  bool isDeleted = false,
}) {
  return MessageItemDto(
    id: id,
    message: text,
    messageType: 'text',
    sender: const SenderDto(uid: 2, name: 'sender', gender: 0),
    chatId: chatId,
    createdAt: createdAt,
    isDeleted: isDeleted,
    replyRootId: replyRootId,
    attachments: const [],
    mentions: const [],
    reactions: const [],
    clientGeneratedId: '',
    sticker: null,
    replyToMessage: null,
    threadInfo: null,
    hasAttachments: false,
  );
}
