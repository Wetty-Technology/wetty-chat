import 'package:chahua/features/chats/conversation_v2/domain/conversation_message_v2.dart';
import 'package:flutter/foundation.dart';

@immutable
class ConversationTimelineV2ActiveSegmentMode {
  const ConversationTimelineV2ActiveSegmentMode.latest({
    this.latestSplitAfterServerMessageId,
  }) : targetServerMessageId = null;

  const ConversationTimelineV2ActiveSegmentMode.around(
    this.targetServerMessageId,
  ) : latestSplitAfterServerMessageId = null;

  final int? targetServerMessageId;
  final int? latestSplitAfterServerMessageId;

  bool get isLatest => targetServerMessageId == null;

  int? get splitAfterServerMessageId =>
      isLatest ? latestSplitAfterServerMessageId : targetServerMessageId!;

  @override
  bool operator ==(Object other) {
    return other is ConversationTimelineV2ActiveSegmentMode &&
        other.targetServerMessageId == targetServerMessageId &&
        other.latestSplitAfterServerMessageId ==
            latestSplitAfterServerMessageId;
  }

  @override
  int get hashCode =>
      Object.hash(targetServerMessageId, latestSplitAfterServerMessageId);
}

/// A single contiguous working segment handed from the repository to the view
/// model. Unlike the canonical store, which may cache multiple discontiguous
/// segments, the view model only consumes one active segment at a time.
typedef ConversationTimelineV2ActiveSegment = ({
  List<ConversationMessageV2> orderedMessages,
  bool canLoadBefore,
  bool canLoadAfter,
  bool isLatestSlice,
});
