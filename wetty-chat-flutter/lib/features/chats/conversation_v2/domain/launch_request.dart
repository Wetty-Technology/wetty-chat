sealed class LaunchRequest {
  const LaunchRequest();

  const factory LaunchRequest.latest() = LatestLaunchRequest;

  const factory LaunchRequest.unread({required int lastReadMessageId}) =
      UnreadLaunchRequest;

  const factory LaunchRequest.message({
    required int messageId,
    bool highlight,
  }) = MessageLaunchRequest;

  bool get isLatest => this is LatestLaunchRequest;
  bool get isUnread => this is UnreadLaunchRequest;

  @override
  bool operator ==(Object other) {
    return switch ((this, other)) {
      (LatestLaunchRequest(), LatestLaunchRequest()) => true,
      (
        UnreadLaunchRequest(:final lastReadMessageId),
        UnreadLaunchRequest(lastReadMessageId: final otherLastReadMessageId),
      ) =>
        lastReadMessageId == otherLastReadMessageId,
      (
        MessageLaunchRequest(:final messageId, :final highlight),
        MessageLaunchRequest(
          messageId: final otherMessageId,
          highlight: final otherHighlight,
        ),
      ) =>
        messageId == otherMessageId && highlight == otherHighlight,
      _ => false,
    };
  }

  @override
  int get hashCode => switch (this) {
    LatestLaunchRequest() => Object.hash(runtimeType, null),
    UnreadLaunchRequest(:final lastReadMessageId) => Object.hash(
      runtimeType,
      lastReadMessageId,
    ),
    MessageLaunchRequest(:final messageId, :final highlight) => Object.hash(
      runtimeType,
      messageId,
      highlight,
    ),
  };
}

final class LatestLaunchRequest extends LaunchRequest {
  const LatestLaunchRequest();
}

final class UnreadLaunchRequest extends LaunchRequest {
  const UnreadLaunchRequest({required this.lastReadMessageId});

  final int lastReadMessageId;
}

final class MessageLaunchRequest extends LaunchRequest {
  const MessageLaunchRequest({required this.messageId, this.highlight = true});

  final int messageId;
  final bool highlight;
}
