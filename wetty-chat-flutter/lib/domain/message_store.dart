import '../data/models/message_models.dart';

// ---------------------------------------------------------------------------
// Message store with sorted ranges
// ---------------------------------------------------------------------------

class MessageRange {
  final List<MessageItem> messages;

  MessageRange({required this.messages});

  int get start => int.parse(messages.first.id);
  int get end => int.parse(messages.last.id);

  // void _updateBounds() {
  //   if (messages.isEmpty) return;
  //   start = messages.last.id; // oldest
  //   end = messages.first.id; // newest
  // }
}

class MessageStore {
  // ranges will be inserted in order
  final List<MessageRange> messageRanges = [];

  // Add a batch of messages from fetching: find overlapping ranges, merge them.
  void addMessages(List<MessageItem> items) {
    if (items.isEmpty) return;

    // new message range
    final range = MessageRange(messages: items);

    // TODO: change this when have overlapped ranges
    // Linear search to insert range sorted descending by end
    int insertAt = messageRanges.length;
    for (int i = 0; i < messageRanges.length; i++) {
      if (range.end >= messageRanges[i].end) {
        insertAt = i;
        break;
      }
    }
    messageRanges.insert(insertAt, range);

    // // Find all existing ranges that overlap with [oldest, newest]
    // final overlapping = <int>[];
    // for (int i = 0; i < ranges.length; i++) {
    //   final r = ranges[i];
    //   // Overlap if: newOldest <= rangeNewest AND newNewest >= rangeOldest
    //   if (MessageRange.cmp(oldest, r.end) <= 0 &&
    //       MessageRange.cmp(newest, r.start) >= 0) {
    //     overlapping.add(i);
    //   }
    // }

    // if (overlapping.isEmpty) {
    //   // No overlap — create a new range
    //   final range = MessageRange(start: oldest, end: newest);
    //   range.insertAll(items);
    //   ranges.add(range);
    // } else {
    //   // Merge: pick the first overlapping range as target, absorb others + new items
    //   final targetIdx = overlapping.first;
    //   final target = ranges[targetIdx];

    //   // Absorb messages from all other overlapping ranges
    //   for (int i = overlapping.length - 1; i >= 1; i--) {
    //     final otherIdx = overlapping[i];
    //     target.insertAll(ranges[otherIdx].messages);
    //     ranges.removeAt(otherIdx);
    //   }

    //   // Insert the new items
    //   target.insertAll(items);
    // }
  }

  /// Flatten all sorted ranges into one list
  List<MessageItem> buildDisplayItems() {
    // Put all messages together
    final all = <MessageItem>[];
    for (final r in messageRanges) {
      all.addAll(r.messages);
    }
    return all;
  }

  void clear() {
    messageRanges.clear();
  }

  /// Remove a message by ID from whichever range contains it.
  void removeById(String id) {
    // TODO: can use binary search to remove
    for (final r in messageRanges) {
      final removed = r.messages.where((m) => m.id == id).isNotEmpty;
      if (removed) {
        r.messages.removeWhere((m) => m.id == id);
        break;
      }
    }
  }

  /// Find and replace a message across all ranges.
  void replaceWhere(bool Function(MessageItem) test, MessageItem replacement) {
    for (final r in messageRanges) {
      final idx = r.messages.indexWhere(test);
      if (idx >= 0) {
        r.messages[idx] = replacement;
        return;
      }
    }
  }

  /// Remove messages matching a test from all ranges.
  void removeWhere(bool Function(MessageItem) test) {
    for (final r in messageRanges) {
      r.messages.removeWhere(test);
    }
  }

  bool get isEmpty =>
      messageRanges.isEmpty || messageRanges.every((r) => r.messages.isEmpty);
  bool get isNotEmpty => !isEmpty;

  /// Oldest loaded ID (for "load more" before param).
  String? get oldestId =>
      messageRanges.isNotEmpty ? messageRanges.last.start.toString() : null;

  /// Insert a single message into the newest range (for optimistic send).
  /// Temp messages are always the newest, so insert at front.
  // void insertIntoNewestRange(MessageItem msg) {
  //   if (messageRanges.isNotEmpty) {
  //     messageRanges.first.messages.insert(0, msg);
  //   } else {
  //     final range = MessageRange(
  //       start: BigInt.parse(msg.id),
  //       end: BigInt.parse(msg.id),
  //     );
  //     range.messages.add(msg);
  //     messageRanges.add(range);
  //   }
  // }
}
