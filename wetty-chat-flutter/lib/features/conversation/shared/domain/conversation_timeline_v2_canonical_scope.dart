import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:chahua/features/conversation/shared/domain/conversation_message_v2.dart';

part 'conversation_timeline_v2_canonical_scope.freezed.dart';

/// A canonical segment is a contiguous range of messages that are sorted by server message id.
class ConversationTimelineV2CanonicalSegment {
  ConversationTimelineV2CanonicalSegment({
    required List<ConversationMessageV2> orderedMessages,
  }) : assert(orderedMessages.isNotEmpty, 'canonical segment cannot be empty'),
       assert(
         orderedMessages.every((message) => message.serverMessageId != null),
         'canonical segment messages must all have server ids',
       ),
       orderedMessages = List<ConversationMessageV2>.unmodifiable(
         orderedMessages,
       );

  final List<ConversationMessageV2> orderedMessages;

  int get firstServerMessageId => orderedMessages.first.serverMessageId!;

  int get lastServerMessageId => orderedMessages.last.serverMessageId!;

  /// Returns true if this is "fully" before the other segment (no overlap).
  bool isStrictlyBefore(ConversationTimelineV2CanonicalSegment other) {
    return lastServerMessageId < other.firstServerMessageId;
  }

  bool overlaps(ConversationTimelineV2CanonicalSegment other) {
    return firstServerMessageId <= other.lastServerMessageId &&
        other.firstServerMessageId <= lastServerMessageId;
  }

  bool endsBeforeServerMessageId(int serverMessageIdExclusive) {
    return lastServerMessageId < serverMessageIdExclusive;
  }

  bool startsAtOrAfterServerMessageId(int serverMessageIdInclusive) {
    return firstServerMessageId >= serverMessageIdInclusive;
  }

  bool startsAfterServerMessageId(int serverMessageIdExclusive) {
    return firstServerMessageId > serverMessageIdExclusive;
  }

  bool endsAtOrBeforeServerMessageId(int serverMessageIdInclusive) {
    return lastServerMessageId <= serverMessageIdInclusive;
  }

  ConversationTimelineV2CanonicalSegment? messagesBefore(
    int serverMessageIdExclusive,
  ) {
    final prefix = orderedMessages
        .where((message) => message.serverMessageId! < serverMessageIdExclusive)
        .toList(growable: false);
    if (prefix.isEmpty) {
      return null;
    }
    return ConversationTimelineV2CanonicalSegment(orderedMessages: prefix);
  }

  ConversationTimelineV2CanonicalSegment? messagesThrough(
    int serverMessageIdInclusive,
  ) {
    final prefix = orderedMessages
        .where(
          (message) => message.serverMessageId! <= serverMessageIdInclusive,
        )
        .toList(growable: false);
    if (prefix.isEmpty) {
      return null;
    }
    return ConversationTimelineV2CanonicalSegment(orderedMessages: prefix);
  }

  ConversationTimelineV2CanonicalSegment? messagesFrom(
    int serverMessageIdInclusive,
  ) {
    final suffix = orderedMessages
        .where(
          (message) => message.serverMessageId! >= serverMessageIdInclusive,
        )
        .toList(growable: false);
    if (suffix.isEmpty) {
      return null;
    }
    return ConversationTimelineV2CanonicalSegment(orderedMessages: suffix);
  }

  ConversationTimelineV2CanonicalSegment? messagesAfter(
    int serverMessageIdExclusive,
  ) {
    final suffix = orderedMessages
        .where((message) => message.serverMessageId! > serverMessageIdExclusive)
        .toList(growable: false);
    if (suffix.isEmpty) {
      return null;
    }
    return ConversationTimelineV2CanonicalSegment(orderedMessages: suffix);
  }
}

@freezed
abstract class ConversationTimelineV2CanonicalScope
    with _$ConversationTimelineV2CanonicalScope {
  const factory ConversationTimelineV2CanonicalScope({
    @Default(<ConversationTimelineV2CanonicalSegment>[])
    List<ConversationTimelineV2CanonicalSegment> segments,
    @Default(false) bool hasLatestSegment,
    @Default(false) bool hasReachedOldest,
    @Default(<ConversationMessageV2>[])
    List<ConversationMessageV2> optimisticMessages,
  }) = _ConversationTimelineV2CanonicalScope;
}
