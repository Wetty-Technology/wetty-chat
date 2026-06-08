import 'package:chahua/core/api/models/saved_messages_api_models.dart';
import 'package:chahua/features/saved_messages/domain/saved_message_target.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SavedMessageTarget', () {
    test('targets the chat for top-level saved messages', () {
      final target = SavedMessageTarget.fromSavedMessage(_savedMessage(10));

      expect(target.chatId, 42);
      expect(target.messageId, 10);
      expect(target.threadRootId, isNull);
    });

    test('targets the thread for saved replies', () {
      final target = SavedMessageTarget.fromSavedMessage(
        _savedMessage(11, threadRootId: 9),
      );

      expect(target.chatId, 42);
      expect(target.messageId, 11);
      expect(target.threadRootId, 9);
    });
  });
}

SavedMessageResponseDto _savedMessage(int messageId, {int? threadRootId}) {
  return SavedMessageResponseDto(
    id: 1,
    originalChatId: 42,
    originalThreadRootId: threadRootId,
    originalMessageId: messageId,
    originalSenderUid: 7,
    originalCreatedAt: DateTime.utc(2026),
    savedAt: DateTime.utc(2026),
    message: 'hello',
    messageType: 'text',
    sender: const SavedSenderSnapshotDto(uid: 7, name: 'Alice', gender: 0),
    chat: const SavedChatSnapshotDto(id: 42, name: 'General'),
    canLocateContext: true,
  );
}
