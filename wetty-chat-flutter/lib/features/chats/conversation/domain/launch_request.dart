enum LaunchRequestIntent { latest, unread, message }

class LaunchRequest {
  const LaunchRequest._({
    required this.intent,
    this.messageId,
    this.highlight = false,
  });

  const LaunchRequest.latest() : this._(intent: LaunchRequestIntent.latest);

  const LaunchRequest.unread(int unreadMessageId)
    : this._(intent: LaunchRequestIntent.unread, messageId: unreadMessageId);

  const LaunchRequest.message(int messageId, {bool highlight = true})
    : this._(
        intent: LaunchRequestIntent.message,
        messageId: messageId,
        highlight: highlight,
      );

  final LaunchRequestIntent intent;
  final int? messageId;
  final bool highlight;

  bool get isLatest => intent == LaunchRequestIntent.latest;
  bool get isUnread => intent == LaunchRequestIntent.unread;

  @override
  bool operator ==(Object other) {
    return other is LaunchRequest &&
        other.intent == intent &&
        other.messageId == messageId &&
        other.highlight == highlight;
  }

  @override
  int get hashCode => Object.hash(intent, messageId, highlight);
}
