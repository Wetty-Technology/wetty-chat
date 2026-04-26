class MessageVisibilityWindow {
  const MessageVisibilityWindow({
    required this.firstVisibleMessageId,
    required this.lastVisibleMessageId,
  });

  final int firstVisibleMessageId;
  final int lastVisibleMessageId;

  @override
  bool operator ==(Object other) {
    return other is MessageVisibilityWindow &&
        other.firstVisibleMessageId == firstVisibleMessageId &&
        other.lastVisibleMessageId == lastVisibleMessageId;
  }

  @override
  int get hashCode => Object.hash(firstVisibleMessageId, lastVisibleMessageId);

  @override
  String toString() {
    return 'MessageVisibilityWindow(firstVisibleMessageId: $firstVisibleMessageId, lastVisibleMessageId: $lastVisibleMessageId)';
  }
}
