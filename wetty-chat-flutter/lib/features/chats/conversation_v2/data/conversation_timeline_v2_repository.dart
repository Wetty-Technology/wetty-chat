abstract class ConversationTimelineV2Repository {
  Future<void> refreshLatestSegment({required int limit});

  Future<void> loadOlderBeforeAnchor(
    int anchorServerMessageId, {
    required int limit,
  });

  Future<void> loadNewerAfterAnchor(
    int anchorServerMessageId, {
    required int limit,
  });

  Future<void> refreshAroundServerMessageId(
    int targetServerMessageId, {
    required int limit,
  });

  Future<void> addLatestFakeMessage();
}
