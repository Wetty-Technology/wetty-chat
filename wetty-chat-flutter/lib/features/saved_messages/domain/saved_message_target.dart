import 'package:chahua/core/api/models/saved_messages_api_models.dart';

class SavedMessageTarget {
  const SavedMessageTarget({
    required this.chatId,
    required this.messageId,
    this.threadRootId,
  });

  final int chatId;
  final int messageId;
  final int? threadRootId;

  factory SavedMessageTarget.fromSavedMessage(SavedMessageResponseDto saved) {
    return SavedMessageTarget(
      chatId: saved.originalChatId,
      messageId: saved.originalMessageId,
      threadRootId: saved.originalThreadRootId,
    );
  }
}
