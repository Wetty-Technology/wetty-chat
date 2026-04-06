class ConversationScope {
  const ConversationScope._({required this.chatId, this.threadRootId});

  const ConversationScope.chat(String chatId) : this._(chatId: chatId);

  const ConversationScope.thread(String chatId, String threadRootId)
    : this._(chatId: chatId, threadRootId: threadRootId);

  final String chatId;
  final String? threadRootId;

  bool get isThread => threadRootId != null;

  String get storageKey => isThread ? '$chatId::thread::$threadRootId' : chatId;

  @override
  bool operator ==(Object other) {
    return other is ConversationScope &&
        other.chatId == chatId &&
        other.threadRootId == threadRootId;
  }

  @override
  int get hashCode => Object.hash(chatId, threadRootId);

  @override
  String toString() => 'ConversationScope($storageKey)';
}
