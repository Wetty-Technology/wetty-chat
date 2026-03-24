import 'package:flutter/foundation.dart';
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

class MessageStore extends ChangeNotifier {
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
    notifyListeners();
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
    notifyListeners();
  }

  /// Remove a message by ID from whichever range contains it.
  void removeById(String id) {
    // TODO: can use binary search to remove
    for (final r in messageRanges) {
      final removed = r.messages.where((m) => m.id == id).isNotEmpty;
      if (removed) {
        r.messages.removeWhere((m) => m.id == id);
        notifyListeners();
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
        notifyListeners();
        return;
      }
    }
  }

  /// Remove messages matching a test from all ranges.
  void removeWhere(bool Function(MessageItem) test) {
    bool changed = false;
    for (final r in messageRanges) {
      final initialCount = r.messages.length;
      r.messages.removeWhere(test);
      if (r.messages.length != initialCount) {
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
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
