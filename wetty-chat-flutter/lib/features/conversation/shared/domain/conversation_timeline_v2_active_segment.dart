import 'package:chahua/features/shared/model/message/message.dart';
import 'package:flutter/foundation.dart';

@immutable
class ConversationTimelineActiveSegmentMode {
  const ConversationTimelineActiveSegmentMode.latest()
    : targetServerMessageId = null;

  const ConversationTimelineActiveSegmentMode.around(
    this.targetServerMessageId,
  );

  final int? targetServerMessageId;

  bool get isLatest => targetServerMessageId == null;

  @override
  bool operator ==(Object other) {
    return other is ConversationTimelineActiveSegmentMode &&
        other.targetServerMessageId == targetServerMessageId;
  }

  @override
  int get hashCode => targetServerMessageId.hashCode;
}

/// A single contiguous working segment handed from the repository to the view
/// model. Unlike the canonical store, which may cache multiple discontiguous
/// segments, the view model only consumes one active segment at a time.
typedef ConversationTimelineActiveSegment = ({
  List<ConversationMessageV2> orderedMessages,
  bool canLoadBefore,
  bool canLoadAfter,
  bool isLatestSlice,
});
