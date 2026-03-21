import '../data/models/message_models.dart';

// ---------------------------------------------------------------------------
// Message store with sorted ranges
// ---------------------------------------------------------------------------

class MessageRange {
  BigInt start; // Oldest message ID
  BigInt end; // Newest message ID
  final List<MessageItem> messages = []; // Sorted newest→oldest (desc by ID)

  MessageRange({required this.start, required this.end});

  // /// Binary-search insert: keeps descending order, skips duplicates.
  // bool insertSorted(MessageItem msg) {
  //   int lo = 0, hi = messages.length;
  //   while (lo < hi) {
  //     final mid = (lo + hi) >> 1;
  //     final c = cmp(messages[mid].id, msg.id);
  //     if (c == 0) return false; // duplicate
  //     if (c > 0) {
  //       lo = mid + 1; // messages[mid] is newer → go right
  //     } else {
  //       hi = mid; // messages[mid] is older → go left
  //     }
  //   }
  //   messages.insert(lo, msg);
  //   _updateBounds();
  //   return true;
  // }

  // /// Bulk insert.
  // void insertAll(List<MessageItem> items) {
  //   for (final m in items) {
  //     insertSorted(m);
  //   }
  // }

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

    // Sort newest→oldest (descending by ID as BigInt)
    items.sort((a, b) {
      return BigInt.parse(b.id).compareTo(BigInt.parse(a.id));
    });

    // new message range
    final newest = BigInt.parse(items.first.id);
    final oldest = BigInt.parse(items.last.id);
    final range = MessageRange(start: oldest, end: newest);

    // TODO: change this when have overlaped ranges
    range.messages.addAll(items);
    // Binary-search insert to keep ranges sorted desc by end
    int lo = 0, hi = messageRanges.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (messageRanges[mid].end.compareTo(newest) > 0) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    messageRanges.insert(lo, range);

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

    // // Keep ranges sorted desc by end
    // ranges.sort((a, b) => MessageRange.cmp(b.end, a.end));
  }

  /// Flatten all sorted ranges into one list (newest→oldest).
  List<MessageItem> buildDisplayItems() {
    // Put all messages together
    final all = <MessageItem>[];
    for (final r in messageRanges) {
      all.addAll(r.messages);
    }
    all.sort((a, b) => b.id.compareTo(a.id));
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
