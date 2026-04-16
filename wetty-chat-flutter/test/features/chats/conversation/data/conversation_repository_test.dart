import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chahua/core/api/models/messages_api_models.dart';
import 'package:chahua/core/api/models/websocket_api_models.dart';
import 'package:chahua/features/chats/conversation/application/conversation_cache_revision_registry.dart';
import 'package:chahua/features/chats/conversation/data/conversation_repository.dart';
import 'package:chahua/features/chats/conversation/data/message_api_service.dart';
import 'package:chahua/features/chats/conversation/domain/conversation_message.dart';
import 'package:chahua/features/chats/conversation/domain/conversation_scope.dart';
import 'package:chahua/features/chats/message_domain/domain/message_domain_store.dart';
import 'package:chahua/features/chats/models/message_models.dart';

void main() {
  group('ConversationRepository sends', () {
    test('commitSend forwards audio message type and attachment ids', () async {
      final service = _FakeMessageApiService(messages: const []);
      final repository = ConversationRepository(
        scope: const ConversationScope.chat(chatId: '1'),
        service: service,
        store: MessageDomainStore(),
      );

      repository.insertOptimisticSend(
        sender: const Sender(uid: 7, name: 'Tester'),
        text: '',
        messageType: 'audio',
        attachments: const [
          AttachmentItem(
            id: 'att-1',
            url: '',
            kind: 'audio/mp4',
            size: 0,
            fileName: 'att-1',
          ),
        ],
        clientGeneratedId: 'audio-cg-1',
        replyToId: 7,
      );

      await repository.commitSend(
        clientGeneratedId: 'audio-cg-1',
        text: '',
        messageType: 'audio',
        attachmentIds: const ['att-1'],
        replyToId: 7,
      );

      expect(service.lastSendMessageType, 'audio');
      expect(service.lastSendText, '');
      expect(service.lastSendAttachmentIds, const ['att-1']);
      expect(service.lastSendReplyToId, 7);
    });

    test(
      'commitSend marks optimistic message sent without assigning server id',
      () async {
        final service = _FakeMessageApiService(messages: const []);
        final repository = ConversationRepository(
          scope: const ConversationScope.chat(chatId: '1'),
          service: service,
          store: MessageDomainStore(),
        );

        final optimistic = repository.insertOptimisticSend(
          sender: const Sender(uid: 7, name: 'Tester'),
          text: 'hello',
          messageType: 'text',
          attachments: const [],
          clientGeneratedId: 'pending-http-1',
        );

        final accepted = await repository.commitSend(
          clientGeneratedId: 'pending-http-1',
          text: 'hello',
          messageType: 'text',
          attachmentIds: const <String>[],
        );

        expect(accepted.localMessageId, optimistic.localMessageId);
        expect(accepted.serverMessageId, isNull);
        expect(accepted.deliveryState, ConversationDeliveryState.sent);
      },
    );

    test(
      'commitSend does not downgrade a message already confirmed by websocket',
      () async {
        final service = _FakeMessageApiService(messages: const []);
        final store = MessageDomainStore();
        final repository = ConversationRepository(
          scope: const ConversationScope.chat(chatId: '1'),
          service: service,
          store: store,
        );

        repository.insertOptimisticSend(
          sender: const Sender(uid: 7, name: 'Tester'),
          text: 'hello',
          messageType: 'text',
          attachments: const [],
          clientGeneratedId: 'pending-race-1',
        );

        final handled = repository.applyRealtimeEvent(
          MessageCreatedWsEvent(
            payload: _message(
              id: 42,
              message: 'hello',
              clientGeneratedId: 'pending-race-1',
            ),
          ),
        );

        expect(handled, isTrue);
        expect(
          store.messageForServerId(42)?.deliveryState,
          ConversationDeliveryState.confirmed,
        );

        final accepted = await repository.commitSend(
          clientGeneratedId: 'pending-race-1',
          text: 'hello',
          messageType: 'text',
          attachmentIds: const <String>[],
        );

        expect(accepted.serverMessageId, 42);
        expect(accepted.deliveryState, ConversationDeliveryState.confirmed);
      },
    );
  });

  group('ConversationRepository refresh reconciliation', () {
    test(
      'refreshLatestWindow confirms a pending optimistic message by clientGeneratedId',
      () async {
        final service = _FakeMessageApiService(messages: const []);
        final repository = ConversationRepository(
          scope: const ConversationScope.chat(chatId: '1'),
          service: service,
          store: MessageDomainStore(),
        );

        await repository.loadLatestWindow();
        final optimistic = repository.insertOptimisticSend(
          sender: const Sender(uid: 7, name: 'Tester'),
          text: 'pending hello',
          messageType: 'text',
          attachments: const [],
          clientGeneratedId: 'pending-1',
        );

        service.replaceMessages([
          _message(
            id: 2,
            message: 'pending hello',
            clientGeneratedId: 'pending-1',
          ),
        ]);

        final refreshed = await repository.refreshLatestWindow();

        expect(refreshed, hasLength(1));
        expect(refreshed.single.serverMessageId, 2);
        expect(
          refreshed.single.deliveryState,
          ConversationDeliveryState.confirmed,
        );
        expect(refreshed.single.localMessageId, optimistic.localMessageId);
        expect(
          repository.messageForServerId(2)?.clientGeneratedId,
          'pending-1',
        );
      },
    );

    test(
      'refreshLatestWindow removes stale confirmed rows absent from backend',
      () async {
        final service = _FakeMessageApiService(
          messages: [_message(id: 1), _message(id: 2)],
        );
        final repository = ConversationRepository(
          scope: const ConversationScope.chat(chatId: '1'),
          service: service,
          store: MessageDomainStore(),
        );

        await repository.loadLatestWindow();
        service.replaceMessages([_message(id: 2)]);

        final refreshed = await repository.refreshLatestWindow();

        expect(refreshed.map((message) => message.serverMessageId).toList(), [
          2,
        ]);
        expect(repository.messageForServerId(1), isNotNull);
      },
    );

    test(
      'websocket delete hides an off-screen deleted non-anchor message when projecting an old window',
      () async {
        final service = _FakeMessageApiService(
          messages: [_message(id: 1), _message(id: 2), _message(id: 3)],
        );
        final repository = ConversationRepository(
          scope: const ConversationScope.chat(chatId: '1'),
          service: service,
          store: MessageDomainStore(),
        );

        await repository.loadLatestWindow();
        final oldWindow = repository.latestWindowStableKeys();

        final handled = repository.applyRealtimeEvent(
          MessageDeletedWsEvent(
            payload: _message(id: 2, isDeleted: true, message: 'Deleted'),
          ),
        );

        expect(handled, isTrue);
        expect(
          repository
              .messagesForWindow(oldWindow)
              .map((message) => message.serverMessageId)
              .toList(),
          [1, 3],
        );
      },
    );

    test(
      'refresh keeps deleted thread anchors visible in chat scope',
      () async {
        final service = _FakeMessageApiService(
          messages: [
            _message(
              id: 10,
              message: 'Anchor',
              threadInfo: const ThreadInfoDto(replyCount: 1),
            ),
            _message(id: 20, message: 'reply', replyRootId: 10),
          ],
        );
        final store = MessageDomainStore();
        final chatRepository = ConversationRepository(
          scope: const ConversationScope.chat(chatId: '1'),
          service: service,
          store: store,
        );
        final threadRepository = ConversationRepository(
          scope: const ConversationScope.thread(
            chatId: '1',
            threadRootId: '10',
          ),
          service: service,
          store: store,
        );

        await chatRepository.loadLatestWindow();
        await threadRepository.loadLatestWindow();

        final handled = chatRepository.applyRealtimeEvent(
          MessageDeletedWsEvent(
            payload: _message(
              id: 10,
              message: 'Anchor',
              isDeleted: true,
              threadInfo: const ThreadInfoDto(replyCount: 1),
            ),
          ),
        );
        expect(handled, isTrue);

        service.replaceMessages([_message(id: 11, message: 'newer root')]);
        final refreshed = await chatRepository.refreshLatestWindow();

        expect(
          refreshed.map(
            (message) => (message.serverMessageId, message.isDeleted),
          ),
          [(10, true), (11, false)],
        );
        expect(refreshed.first.threadInfo?.replyCount, 1);
      },
    );

    test(
      'parent chat and thread repositories converge independently with shared store',
      () async {
        final service = _FakeMessageApiService(
          messages: [
            _message(
              id: 10,
              message: 'Anchor',
              threadInfo: const ThreadInfoDto(replyCount: 1),
            ),
            _message(id: 11, message: 'Root two'),
            _message(id: 20, message: 'reply one', replyRootId: 10),
          ],
        );
        final store = MessageDomainStore();
        final chatRepository = ConversationRepository(
          scope: const ConversationScope.chat(chatId: '1'),
          service: service,
          store: store,
        );
        final threadRepository = ConversationRepository(
          scope: const ConversationScope.thread(
            chatId: '1',
            threadRootId: '10',
          ),
          service: service,
          store: store,
        );

        expect(
          (await chatRepository.loadLatestWindow())
              .map((message) => message.serverMessageId)
              .toList(),
          [10, 11],
        );
        expect(
          (await threadRepository.loadLatestWindow())
              .map((message) => message.serverMessageId)
              .toList(),
          [10, 20],
        );

        final replyEvent = MessageCreatedWsEvent(
          payload: _message(id: 21, message: 'reply two', replyRootId: 10),
        );
        service.appendMessage(
          _message(id: 21, message: 'reply two', replyRootId: 10),
        );

        expect(chatRepository.applyRealtimeEvent(replyEvent), isFalse);
        expect(threadRepository.applyRealtimeEvent(replyEvent), isTrue);
        expect(
          chatRepository.loadLatestWindow().then(
            (messages) => messages.map((m) => m.serverMessageId).toList(),
          ),
          completion([10, 11]),
        );
        expect(
          threadRepository
              .latestWindowStableKeys()
              .map(
                (stableKey) => threadRepository
                    .messagesForWindow([stableKey])
                    .single
                    .serverMessageId,
              )
              .toList(),
          [10, 20, 21],
        );

        service.appendMessage(_message(id: 12, message: 'Root three'));
        final refreshedChat = await chatRepository.refreshLatestWindow();
        expect(
          refreshedChat.map((message) => message.serverMessageId).toList(),
          [10, 11, 12],
        );
        expect(
          threadRepository
              .latestWindowStableKeys()
              .map(
                (stableKey) => threadRepository
                    .messagesForWindow([stableKey])
                    .single
                    .serverMessageId,
              )
              .toList(),
          [10, 20, 21],
        );

        service.appendMessage(
          _message(id: 22, message: 'reply three', replyRootId: 10),
        );
        final refreshedThread = await threadRepository.refreshLatestWindow();
        expect(
          refreshedThread.map((message) => message.serverMessageId).toList(),
          [10, 20, 21, 22],
        );
        expect(
          chatRepository
              .latestWindowStableKeys()
              .map(
                (stableKey) => chatRepository
                    .messagesForWindow([stableKey])
                    .single
                    .serverMessageId,
              )
              .toList(),
          [10, 11, 12],
        );
      },
    );

    test(
      'chat-scope realtime root message create is inserted into visible window',
      () async {
        final service = _FakeMessageApiService(
          messages: [
            _message(id: 10, message: 'Root one'),
            _message(id: 11, message: 'Root two'),
          ],
        );
        final repository = ConversationRepository(
          scope: const ConversationScope.chat(chatId: '1'),
          service: service,
          store: MessageDomainStore(),
        );

        await repository.loadLatestWindow();

        final handled = repository.applyRealtimeEvent(
          MessageCreatedWsEvent(
            payload: _message(id: 12, message: 'Root three'),
          ),
        );

        expect(handled, isTrue);
        expect(
          repository
              .latestWindowStableKeys()
              .map(
                (stableKey) => repository
                    .messagesForWindow([stableKey])
                    .single
                    .serverMessageId,
              )
              .toList(),
          [10, 11, 12],
        );
      },
    );

    test(
      'provider-backed repository bumps scope revision for realtime events',
      () async {
        final service = _FakeMessageApiService(
          messages: [
            _message(id: 10, message: 'Root one'),
            _message(id: 11, message: 'Root two'),
          ],
        );
        final container = ProviderContainer(
          overrides: [messageApiServiceProvider.overrideWithValue(service)],
        );
        addTearDown(container.dispose);
        const scope = ConversationScope.chat(chatId: '1');
        final repository = container.read(
          conversationRepositoryProvider(scope),
        );

        await repository.loadLatestWindow();
        final before = container.read(conversationCacheRevisionProvider(scope));

        final handled = repository.applyRealtimeEvent(
          MessageCreatedWsEvent(
            payload: _message(id: 12, message: 'Root three'),
          ),
        );

        final after = container.read(conversationCacheRevisionProvider(scope));
        expect(handled, isTrue);
        expect(after, greaterThan(before));
      },
    );

    test(
      'loading a historical range does not replace the cached latest range',
      () async {
        final service = _FakeMessageApiService(
          messages: List<MessageItemDto>.generate(
            150,
            (index) => _message(id: index + 1, message: 'Message ${index + 1}'),
          ),
        );
        final repository = ConversationRepository(
          scope: const ConversationScope.chat(chatId: '1'),
          service: service,
          store: MessageDomainStore(),
        );

        await repository.loadLatestWindow();
        final latestBefore = repository.latestWindowStableKeys();

        final historical = await repository.loadAroundMessage(10);
        final latestAfter = repository.latestWindowStableKeys();

        expect(
          historical.map((message) => message.serverMessageId),
          contains(10),
        );
        expect(latestBefore.first, 'server:51');
        expect(latestBefore.last, 'server:150');
        expect(latestAfter, latestBefore);
      },
    );
  });

  group('ConversationRepository reactions', () {
    test(
      'toggleReaction removes an existing self reaction optimistically',
      () async {
        final service = _FakeMessageApiService(
          messages: [
            _message(
              reactions: [
                const ReactionSummaryDto(
                  emoji: '👍',
                  count: 1,
                  reactedByMe: true,
                ),
              ],
            ),
          ],
        );
        final repository = ConversationRepository(
          scope: const ConversationScope.chat(chatId: '1'),
          service: service,
          store: MessageDomainStore(),
        );

        await repository.loadLatestWindow();
        await repository.toggleReaction(messageId: 1, emoji: '👍');

        expect(service.reactionCalls, ['delete:1:👍']);
        expect(repository.messageForServerId(1)?.reactions, isEmpty);
      },
    );

    test(
      'toggleReaction adds a reaction optimistically when missing',
      () async {
        final service = _FakeMessageApiService(messages: [_message()]);
        final repository = ConversationRepository(
          scope: const ConversationScope.chat(chatId: '1'),
          service: service,
          store: MessageDomainStore(),
        );

        await repository.loadLatestWindow();
        await repository.toggleReaction(messageId: 1, emoji: '🔥');

        expect(service.reactionCalls, ['put:1:🔥']);
        expect(repository.messageForServerId(1)?.reactions, [
          const ReactionSummary(emoji: '🔥', count: 1, reactedByMe: true),
        ]);
      },
    );

    test('toggleReaction rolls back when the request fails', () async {
      final service = _FakeMessageApiService(messages: [_message()]);
      service.failPut = true;
      final repository = ConversationRepository(
        scope: const ConversationScope.chat(chatId: '1'),
        service: service,
        store: MessageDomainStore(),
      );

      await repository.loadLatestWindow();

      await expectLater(
        repository.toggleReaction(messageId: 1, emoji: '🔥'),
        throwsException,
      );

      expect(service.reactionCalls, ['put:1:🔥']);
      expect(repository.messageForServerId(1)?.reactions, isEmpty);
    });

    test(
      'reactionUpdated websocket events override the cached reaction summary',
      () async {
        final service = _FakeMessageApiService(
          messages: [
            _message(
              reactions: [
                const ReactionSummaryDto(
                  emoji: '👍',
                  count: 1,
                  reactedByMe: true,
                ),
              ],
            ),
          ],
        );
        final repository = ConversationRepository(
          scope: const ConversationScope.chat(chatId: '1'),
          service: service,
          store: MessageDomainStore(),
        );

        await repository.loadLatestWindow();
        final handled = repository.applyRealtimeEvent(
          ReactionUpdatedWsEvent(
            payload: ReactionUpdatePayloadDto(
              messageId: 1,
              chatId: 1,
              reactions: [
                ReactionSummaryDto(
                  emoji: '👍',
                  count: 2,
                  reactors: [
                    const ReactionReactorDto(uid: 7, name: 'Tester'),
                    const ReactionReactorDto(uid: 8, name: 'Peer'),
                  ],
                ),
              ],
            ),
          ),
        );

        expect(handled, isTrue);
        expect(repository.messageForServerId(1)?.reactions, [
          const ReactionSummary(
            emoji: '👍',
            count: 2,
            reactedByMe: true,
            reactors: [
              ReactionReactor(uid: 7, name: 'Tester'),
              ReactionReactor(uid: 8, name: 'Peer'),
            ],
          ),
        ]);
      },
    );

    test('toggleReaction rejects stickers', () async {
      final service = _FakeMessageApiService(
        messages: [_message(messageType: 'sticker')],
      );
      final repository = ConversationRepository(
        scope: const ConversationScope.chat(chatId: '1'),
        service: service,
        store: MessageDomainStore(),
      );

      await repository.loadLatestWindow();

      await expectLater(
        repository.toggleReaction(messageId: 1, emoji: '🔥'),
        throwsUnsupportedError,
      );
      expect(service.reactionCalls, isEmpty);
    });
  });
}

MessageItemDto _message({
  int id = 1,
  String? message = 'Hello',
  String messageType = 'text',
  List<AttachmentItemDto> attachments = const <AttachmentItemDto>[],
  List<ReactionSummaryDto> reactions = const <ReactionSummaryDto>[],
  String? clientGeneratedId,
  int? replyRootId,
  bool isDeleted = false,
  ThreadInfoDto? threadInfo,
}) {
  return MessageItemDto(
    id: id,
    message: message,
    messageType: messageType,
    sender: const SenderDto(uid: 7, name: 'Tester'),
    chatId: 1,
    createdAt: DateTime.utc(2026, 1, 1),
    clientGeneratedId: clientGeneratedId ?? 'cg-$id',
    replyRootId: replyRootId,
    isDeleted: isDeleted,
    attachments: attachments,
    reactions: reactions,
    threadInfo: threadInfo,
  );
}

class _FakeMessageApiService extends MessageApiService {
  _FakeMessageApiService({required List<MessageItemDto> messages})
    : _messages = List<MessageItemDto>.of(messages),
      super(Dio(), 1);

  final List<MessageItemDto> _messages;
  final List<String> reactionCalls = <String>[];
  bool failPut = false;
  bool failDelete = false;
  String? lastSendText;
  String? lastSendMessageType;
  List<String>? lastSendAttachmentIds;
  int? lastSendReplyToId;

  void replaceMessages(List<MessageItemDto> messages) {
    _messages
      ..clear()
      ..addAll(messages);
  }

  void appendMessage(MessageItemDto message) {
    _messages.add(message);
  }

  @override
  Future<ListMessagesResponseDto> fetchConversationMessages(
    ConversationScope scope, {
    int? max,
    int? before,
    int? after,
    int? around,
  }) async {
    final scopedMessages = _messagesForScope(scope);
    if (around != null) {
      final index = scopedMessages.indexWhere(
        (message) => message.id == around,
      );
      if (index < 0) {
        return const ListMessagesResponseDto();
      }
      final limit = max ?? scopedMessages.length;
      final beforeCount = (limit - 1) ~/ 2;
      final afterCount = limit - beforeCount - 1;
      final end = (index + afterCount + 1).clamp(0, scopedMessages.length);
      final adjustedStart = (end - limit).clamp(0, scopedMessages.length);
      return ListMessagesResponseDto(
        messages: scopedMessages.sublist(adjustedStart, end),
      );
    }
    if (before != null) {
      final filtered = scopedMessages
          .where((message) => message.id < before)
          .toList(growable: false);
      if (max == null || filtered.length <= max) {
        return ListMessagesResponseDto(messages: filtered);
      }
      return ListMessagesResponseDto(
        messages: filtered.sublist(filtered.length - max),
      );
    }
    if (after != null) {
      final filtered = scopedMessages
          .where((message) => message.id > after)
          .toList(growable: false);
      if (max == null || filtered.length <= max) {
        return ListMessagesResponseDto(messages: filtered);
      }
      return ListMessagesResponseDto(messages: filtered.sublist(0, max));
    }
    if (max == null || scopedMessages.length <= max) {
      return ListMessagesResponseDto(messages: scopedMessages);
    }
    return ListMessagesResponseDto(
      messages: scopedMessages.sublist(scopedMessages.length - max),
    );
  }

  @override
  Future<void> putReaction(
    ConversationScope scope,
    int messageId,
    String emoji,
  ) async {
    reactionCalls.add('put:$messageId:$emoji');
    if (failPut) {
      throw Exception('put failed');
    }
  }

  @override
  Future<void> deleteReaction(
    ConversationScope scope,
    int messageId,
    String emoji,
  ) async {
    reactionCalls.add('delete:$messageId:$emoji');
    if (failDelete) {
      throw Exception('delete failed');
    }
  }

  @override
  Future<MessageItemDto> sendConversationMessage(
    ConversationScope scope,
    String text, {
    required String messageType,
    int? replyToId,
    List<String> attachmentIds = const <String>[],
    required String clientGeneratedId,
    String? stickerId,
  }) async {
    lastSendText = text;
    lastSendMessageType = messageType;
    lastSendAttachmentIds = attachmentIds;
    lastSendReplyToId = replyToId;
    return _message(
      message: text,
      messageType: messageType,
      clientGeneratedId: clientGeneratedId,
      attachments: attachmentIds
          .map(
            (id) => AttachmentItemDto(
              id: id,
              kind: messageType == 'audio' ? 'audio/mp4' : 'application/pdf',
              fileName: id,
            ),
          )
          .toList(growable: false),
    );
  }

  List<MessageItemDto> _messagesForScope(ConversationScope scope) {
    final scoped = _messages
        .where((message) => message.chatId.toString() == scope.chatId)
        .where((message) {
          final threadRootId = scope.threadRootId;
          if (threadRootId == null) {
            return message.replyRootId == null;
          }
          final anchorId = int.parse(threadRootId);
          return (message.replyRootId == null && message.id == anchorId) ||
              message.replyRootId == anchorId;
        })
        .toList(growable: false);
    scoped.sort((left, right) => left.id.compareTo(right.id));
    return scoped;
  }
}
