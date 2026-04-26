import 'package:chahua/features/shared/model/message/message.dart';

class PinnedMessage {
  const PinnedMessage({
    required this.id,
    required this.chatId,
    required this.message,
    required this.pinnedBy,
    required this.pinnedAt,
    this.expiresAt,
  });

  final int id;
  final int chatId;
  final ConversationMessageV2 message;
  final int pinnedBy;
  final DateTime pinnedAt;
  final DateTime? expiresAt;

  int? get messageId => message.serverMessageId;

  PinnedMessage copyWith({ConversationMessageV2? message}) {
    return PinnedMessage(
      id: id,
      chatId: chatId,
      message: message ?? this.message,
      pinnedBy: pinnedBy,
      pinnedAt: pinnedAt,
      expiresAt: expiresAt,
    );
  }
}
