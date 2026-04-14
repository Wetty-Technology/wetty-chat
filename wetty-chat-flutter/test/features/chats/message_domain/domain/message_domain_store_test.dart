import 'package:chahua/features/chats/conversation/domain/conversation_message.dart';
import 'package:chahua/features/chats/conversation/domain/conversation_scope.dart';
import 'package:chahua/features/chats/message_domain/domain/message_domain.dart';
import 'package:chahua/features/chats/models/message_models.dart';
import 'package:flutter_test/flutter_test.dart';

const sender = Sender(uid: 1, name: 'Alice');
const otherSender = Sender(uid: 2, name: 'Bob');
const chatScope = ConversationScope.chat(chatId: 'chat-1');
const threadScope = ConversationScope.thread(
  chatId: 'chat-1',
  threadRootId: '10',
);

void main() {
  group('MessageDomainStore', () {
    test(
      'optimistic thread reply stays out of main chat preview and window',
      () {
        final store = MessageDomainStore();
        store.reconcileFetchedWindow(
          scope: chatScope,
          messages: [
            _serverMessage(
              scope: chatScope,
              id: 10,
              chatId: 'chat-1',
              sender: sender,
              text: 'Anchor',
              threadInfo: const ThreadInfo(replyCount: 0),
            ),
          ],
        );

        store.applyOptimisticThreadReplySend(
          const MessageDomainDraftMessage(
            scope: threadScope,
            clientGeneratedId: 'optimistic-thread-1',
            sender: otherSender,
            message: 'reply',
          ),
        );

        expect(
          store
              .selectVisibleWindow(chatScope)
              .map((message) => message.message),
          ['Anchor'],
        );
        expect(store.selectChatPreview('chat-1')?.message, 'Anchor');
        expect(
          store
              .selectVisibleWindow(threadScope)
              .map((message) => message.message),
          ['Anchor', 'reply'],
        );
        expect(store.selectThreadAnchorState(10)?.replyCount, 1);
      },
    );

    test('delete removes visible row but keeps deleted reply reference', () {
      final store = MessageDomainStore();
      store.reconcileFetchedWindow(
        scope: chatScope,
        messages: [
          _serverMessage(
            scope: chatScope,
            id: 1,
            chatId: 'chat-1',
            sender: sender,
            text: 'hello',
          ),
          _serverMessage(
            scope: chatScope,
            id: 2,
            chatId: 'chat-1',
            sender: otherSender,
            text: 'reply',
          ),
        ],
      );

      store.applyOptimisticDelete(1);
      store.applyDeleteConfirmed(1);

      expect(
        store
            .selectVisibleWindow(chatScope)
            .map((message) => message.serverMessageId),
        [2],
      );
      expect(store.selectReplyReference(1)?.isDeleted, isTrue);
      expect(store.selectReplyReference(1)?.message, isNull);
    });

    test(
      'rollback optimistic delete restores message without wiping later events',
      () {
        final store = MessageDomainStore();
        store.reconcileFetchedWindow(
          scope: chatScope,
          messages: [
            _serverMessage(
              scope: chatScope,
              id: 1,
              chatId: 'chat-1',
              sender: sender,
              text: 'hello',
            ),
            _serverMessage(
              scope: chatScope,
              id: 2,
              chatId: 'chat-1',
              sender: otherSender,
              text: 'world',
            ),
          ],
        );

        store.applyOptimisticDelete(1);
        store.applyWebsocketMessageCreated(
          _serverMessage(
            scope: chatScope,
            id: 3,
            chatId: 'chat-1',
            sender: sender,
            text: 'later',
          ),
        );
        store.rollbackOptimisticDelete(1);

        expect(
          store
              .selectVisibleWindow(chatScope)
              .map((message) => message.serverMessageId),
          [1, 2, 3],
        );
      },
    );

    test(
      'authoritative refresh removes stale confirmed rows and keeps pending optimistic rows',
      () {
        final store = MessageDomainStore();
        store.reconcileFetchedWindow(
          scope: chatScope,
          messages: [
            _serverMessage(
              scope: chatScope,
              id: 1,
              chatId: 'chat-1',
              sender: sender,
              text: 'one',
            ),
            _serverMessage(
              scope: chatScope,
              id: 2,
              chatId: 'chat-1',
              sender: otherSender,
              text: 'two',
            ),
          ],
        );

        store.applyOptimisticNormalMessageSend(
          const MessageDomainDraftMessage(
            scope: chatScope,
            clientGeneratedId: 'local-1',
            sender: sender,
            message: 'pending',
          ),
        );

        store.reconcileFetchedWindow(
          scope: chatScope,
          messages: [
            _serverMessage(
              scope: chatScope,
              id: 2,
              chatId: 'chat-1',
              sender: otherSender,
              text: 'two',
            ),
          ],
        );

        expect(
          store
              .selectVisibleWindow(chatScope)
              .map((message) => message.message),
          ['two', 'pending'],
        );
      },
    );

    test('refresh keeps deleted thread anchors visible in the chat window', () {
      final store = MessageDomainStore();
      _seedAnchorThread(store);

      store.applyOptimisticDelete(10);
      store.applyDeleteConfirmed(10);
      store.reconcileFetchedWindow(
        scope: chatScope,
        messages: [
          _serverMessage(
            scope: chatScope,
            id: 11,
            chatId: 'chat-1',
            sender: otherSender,
            text: 'newer',
          ),
        ],
      );

      final visible = store.selectVisibleWindow(chatScope);
      expect(visible.map((message) => message.serverMessageId), [10, 11]);
      expect(visible.first.isDeleted, isTrue);
      expect(visible.first.threadInfo?.replyCount, 1);
    });

    test(
      'confirming optimistic thread reply reconciles without double increment',
      () {
        final store = MessageDomainStore();
        store.reconcileFetchedWindow(
          scope: chatScope,
          messages: [
            _serverMessage(
              scope: chatScope,
              id: 10,
              chatId: 'chat-1',
              sender: sender,
              text: 'Anchor',
              threadInfo: const ThreadInfo(replyCount: 0),
            ),
          ],
        );

        store.applyOptimisticThreadReplySend(
          const MessageDomainDraftMessage(
            scope: threadScope,
            clientGeneratedId: 'optimistic-thread-1',
            sender: otherSender,
            message: 'reply',
          ),
        );
        store.applySendAccepted('optimistic-thread-1');
        store.applySendConfirmed(
          _serverMessage(
            scope: threadScope,
            id: 20,
            chatId: 'chat-1',
            sender: otherSender,
            text: 'reply',
            clientGeneratedId: 'optimistic-thread-1',
            replyRootId: 10,
          ),
        );

        expect(store.selectThreadAnchorState(10)?.replyCount, 1);
        expect(
          store.messageForServerId(20)?.deliveryState,
          ConversationDeliveryState.confirmed,
        );
        expect(
          store
              .selectVisibleWindow(threadScope)
              .map((message) => message.message),
          ['Anchor', 'reply'],
        );
      },
    );

    test(
      'deleting a thread anchor keeps it visible in chat and thread contexts',
      () {
        final store = MessageDomainStore();
        _seedAnchorThread(store);

        store.applyOptimisticDelete(10);
        store.applyDeleteConfirmed(10);

        final visibleChat = store.selectVisibleWindow(chatScope);
        final visibleThread = store.selectVisibleWindow(threadScope);

        expect(store.isThreadRemoved(10), isFalse);
        expect(visibleChat.map((message) => message.serverMessageId), [10]);
        expect(visibleChat.single.isDeleted, isTrue);
        expect(visibleChat.single.threadInfo?.replyCount, 1);
        expect(visibleThread.map((message) => message.serverMessageId), [
          10,
          20,
        ]);
        expect(visibleThread.first.isDeleted, isTrue);
        expect(
          store
              .selectThreadPreview(chatId: 'chat-1', threadAnchorId: 10)
              ?.message,
          'reply',
        );
      },
    );

    test('deleting all replies keeps the anchor alive with zero replies', () {
      final store = MessageDomainStore();
      _seedAnchorThread(store);

      store.applyOptimisticDelete(20);
      store.applyDeleteConfirmed(20);

      expect(store.selectThreadAnchorState(10)?.replyCount, 0);
      expect(
        store
            .selectVisibleWindow(threadScope)
            .map((message) => message.serverMessageId),
        [10],
      );
      expect(
        store.selectThreadPreview(chatId: 'chat-1', threadAnchorId: 10),
        isNull,
      );
    });

    test(
      'replying to a deleted anchor is allowed and keeps the thread active',
      () {
        final store = MessageDomainStore();
        _seedAnchorThread(store);

        store.applyOptimisticDelete(10);
        store.applyDeleteConfirmed(10);
        store.applyOptimisticThreadReplySend(
          const MessageDomainDraftMessage(
            scope: threadScope,
            clientGeneratedId: 'optimistic-thread-2',
            sender: otherSender,
            message: 'follow-up',
          ),
        );

        expect(store.selectThreadAnchorState(10)?.replyCount, 2);
        expect(
          store
              .selectVisibleWindow(threadScope)
              .map(
                (message) => (
                  message.serverMessageId,
                  message.message,
                  message.isDeleted,
                ),
              ),
          [(10, null, true), (20, 'reply', false), (null, 'follow-up', false)],
        );
        expect(
          store
              .selectThreadPreview(chatId: 'chat-1', threadAnchorId: 10)
              ?.message,
          'follow-up',
        );
      },
    );

    test('retrying a failed thread reply reapplies optimistic reply count', () {
      final store = MessageDomainStore();
      _seedAnchorThread(store);

      store.applyOptimisticThreadReplySend(
        const MessageDomainDraftMessage(
          scope: threadScope,
          clientGeneratedId: 'optimistic-thread-3',
          sender: otherSender,
          message: 'retry me',
        ),
      );
      store.applySendFailed('optimistic-thread-3');

      expect(store.selectThreadAnchorState(10)?.replyCount, 1);

      final failedReply = store.messageForClientGeneratedId(
        'optimistic-thread-3',
      );
      expect(failedReply?.deliveryState, ConversationDeliveryState.failed);

      final retried = store.retryFailedSend(failedReply!);

      expect(retried.deliveryState, ConversationDeliveryState.sending);
      expect(store.selectThreadAnchorState(10)?.replyCount, 2);
    });

    test('accepting an optimistic send keeps it local until confirmation', () {
      final store = MessageDomainStore();

      final optimistic = store.applyOptimisticNormalMessageSend(
        const MessageDomainDraftMessage(
          scope: chatScope,
          clientGeneratedId: 'optimistic-accepted-1',
          sender: sender,
          message: 'hello',
        ),
      );

      final accepted = store.applySendAccepted('optimistic-accepted-1');

      expect(accepted.localMessageId, optimistic.localMessageId);
      expect(accepted.serverMessageId, isNull);
      expect(accepted.deliveryState, ConversationDeliveryState.sent);
    });

    test(
      'accepting an optimistic send never downgrades a confirmed message',
      () {
        final store = MessageDomainStore();

        store.applyOptimisticNormalMessageSend(
          const MessageDomainDraftMessage(
            scope: chatScope,
            clientGeneratedId: 'optimistic-confirmed-1',
            sender: sender,
            message: 'hello',
          ),
        );

        store.applySendConfirmed(
          _serverMessage(
            scope: chatScope,
            id: 99,
            chatId: 'chat-1',
            clientGeneratedId: 'optimistic-confirmed-1',
            sender: sender,
            text: 'hello',
          ),
        );

        final accepted = store.applySendAccepted('optimistic-confirmed-1');

        expect(accepted.serverMessageId, 99);
        expect(accepted.deliveryState, ConversationDeliveryState.confirmed);
      },
    );
  });
}

void _seedAnchorThread(MessageDomainStore store) {
  store.reconcileFetchedWindow(
    scope: chatScope,
    messages: [
      _serverMessage(
        scope: chatScope,
        id: 10,
        chatId: 'chat-1',
        sender: sender,
        text: 'Anchor',
        threadInfo: const ThreadInfo(replyCount: 1),
      ),
    ],
  );
  store.reconcileFetchedWindow(
    scope: threadScope,
    messages: [
      _serverMessage(
        scope: threadScope,
        id: 10,
        chatId: 'chat-1',
        sender: sender,
        text: 'Anchor',
        threadInfo: const ThreadInfo(replyCount: 1),
      ),
      _serverMessage(
        scope: threadScope,
        id: 20,
        chatId: 'chat-1',
        sender: otherSender,
        text: 'reply',
        replyRootId: 10,
      ),
    ],
  );
}

ConversationMessage _serverMessage({
  required ConversationScope scope,
  required int id,
  required String chatId,
  required Sender sender,
  required String text,
  String clientGeneratedId = '',
  int? replyRootId,
  ThreadInfo? threadInfo,
}) {
  return ConversationMessage(
    scope: scope,
    serverMessageId: id,
    clientGeneratedId: clientGeneratedId,
    sender: sender,
    message: text,
    messageType: 'text',
    createdAt: DateTime.utc(2024, 1, 1, 0, 0, id),
    replyRootId: replyRootId,
    threadInfo: threadInfo,
  );
}
