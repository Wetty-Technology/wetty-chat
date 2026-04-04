import 'package:flutter_test/flutter_test.dart';

import 'package:wetty_chat_flutter/features/chats/detail/application/message_store.dart';
import 'package:wetty_chat_flutter/features/chats/models/message_models.dart';

void main() {
  group('MessageStore', () {
    test('realtime newest message extends the live-edge range', () {
      final store = MessageStore();

      store.addMessages([_message(100), _message(90), _message(80)]);
      store.addMessages([_message(150)]);

      expect(store.ranges, hasLength(1));
      expect(store.newest(limit: 4).map((message) => message.id).toList(), [
        150,
        100,
        90,
        80,
      ]);
    });

    test('older page merges into the anchored range', () {
      final store = MessageStore();

      store.addMessages([_message(100), _message(80)]);
      store.addOlderPage(olderThanId: 80, items: [_message(70), _message(50)]);

      expect(store.ranges, hasLength(1));
      expect(
        store.takeOlderAdjacent(80, 2).map((message) => message.id).toList(),
        [70, 50],
      );
    });

    test('ranges only coalesce when they share exact message ids', () {
      final store = MessageStore();

      store.addMessages([_message(300), _message(200)]);
      store.addMessages([_message(200), _message(100)]);

      expect(store.ranges, hasLength(1));
      expect(store.newest(limit: 3).map((message) => message.id).toList(), [
        300,
        200,
        100,
      ]);
    });

    test(
      'detached ranges remain separate without anchor or overlap evidence',
      () {
        final store = MessageStore();

        store.addMessages([_message(300)]);
        store.addMessages([_message(100)]);

        expect(store.ranges, hasLength(2));
        expect(store.newest(limit: 3).map((message) => message.id).toList(), [
          300,
          100,
        ]);
      },
    );
  });
}

MessageItem _message(int id, {String chatId = '1'}) {
  return MessageItem(
    id: id,
    message: 'm$id',
    messageType: 'text',
    sender: const Sender(uid: 2, name: 'tester'),
    chatId: chatId,
    createdAt: '2026-01-01T00:00:00Z',
    isEdited: false,
    isDeleted: false,
    clientGeneratedId: 'c$id',
    hasAttachments: false,
  );
}
