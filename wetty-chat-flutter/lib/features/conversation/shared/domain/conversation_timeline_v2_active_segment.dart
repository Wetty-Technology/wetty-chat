import 'package:chahua/features/conversation/shared/domain/conversation_message_v2.dart';
import 'package:flutter/foundation.dart';

@immutable
class ConversationTimelineV2ActiveSegmentMode {
  const ConversationTimelineV2ActiveSegmentMode.latest()
    : targetServerMessageId = null;

  const ConversationTimelineV2ActiveSegmentMode.around(
    this.targetServerMessageId,
  );

  final int? targetServerMessageId;

  bool get isLatest => targetServerMessageId == null;

  @override
  bool operator ==(Object other) {
    return other is ConversationTimelineV2ActiveSegmentMode &&
        other.targetServerMessageId == targetServerMessageId;
  }

  @override
  int get hashCode => targetServerMessageId.hashCode;
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
