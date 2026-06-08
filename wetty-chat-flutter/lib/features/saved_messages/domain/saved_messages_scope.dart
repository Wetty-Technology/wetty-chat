sealed class SavedMessagesScope {
  const SavedMessagesScope();

  const factory SavedMessagesScope.global() = GlobalSavedMessagesScope;

  const factory SavedMessagesScope.chat(int chatId) = ChatSavedMessagesScope;

  int? get chatId {
    return switch (this) {
      GlobalSavedMessagesScope() => null,
      ChatSavedMessagesScope(:final chatId) => chatId,
    };
  }

  bool get isGlobal => this is GlobalSavedMessagesScope;
}

final class GlobalSavedMessagesScope extends SavedMessagesScope {
  const GlobalSavedMessagesScope();

  @override
  bool operator ==(Object other) => other is GlobalSavedMessagesScope;

  @override
  int get hashCode => Object.hash(GlobalSavedMessagesScope, 0);

  @override
  String toString() => 'SavedMessagesScope.global()';
}

final class ChatSavedMessagesScope extends SavedMessagesScope {
  const ChatSavedMessagesScope(this.chatId);

  @override
  final int chatId;

  @override
  bool operator ==(Object other) {
    return other is ChatSavedMessagesScope && other.chatId == chatId;
  }

  @override
  int get hashCode => Object.hash(ChatSavedMessagesScope, chatId);

  @override
  String toString() => 'SavedMessagesScope.chat($chatId)';
}
