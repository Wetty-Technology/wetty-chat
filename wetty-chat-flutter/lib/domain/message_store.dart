import 'package:flutter/foundation.dart';

import '../data/models/message_models.dart';

/// A contiguous block of messages sorted descending by snowflake ID.
class MessageRange {
  final List<MessageItem> messages;

  MessageRange(List<MessageItem> items) : messages = List.of(items) {
    messages.sort((a, b) => b.id.compareTo(a.id));
  }

  int get end => messages.first.id;
  int get start => messages.last.id;

  bool contains(int messageId) => start <= messageId && messageId <= end;

  bool overlaps(MessageRange other) {
    return start <= other.end && other.start <= end;
  }

  int indexOf(int messageId) {
    return messages.indexWhere((message) => message.id == messageId);
  }

  void mergeWith(MessageRange other) {
    final mergedById = <int, MessageItem>{};
    for (final message in messages) {
      mergedById[message.id] = message;
    }
    for (final message in other.messages) {
      mergedById[message.id] = message;
    }

    messages
      ..clear()
      ..addAll(mergedById.values)
      ..sort((a, b) => b.id.compareTo(a.id));
  }
}

class MessageStore extends ChangeNotifier {
  final List<MessageRange> _ranges = [];
  List<MessageItem>? _cachedItems;

  List<MessageRange> get ranges => List.unmodifiable(_ranges);

  List<MessageItem> get displayItems {
    _cachedItems ??= _buildFlatList();
    return _cachedItems!;
  }

  List<MessageItem> _buildFlatList() {
    final all = <MessageItem>[];
    for (final range in _ranges) {
      all.addAll(range.messages);
    }
    return all;
  }

  void _invalidateCache() {
    _cachedItems = null;
  }

  void clear() {
    _ranges.clear();
    _invalidateCache();
    notifyListeners();
  }

  void addMessages(List<MessageItem> items) {
    _insertRange(MessageRange(items));
  }

  void addOlderPage({required int olderThanId, required List<MessageItem> items}) {
    _addContiguousPage(anchorId: olderThanId, items: items);
  }

  void addNewerPage({required int newerThanId, required List<MessageItem> items}) {
    _addContiguousPage(anchorId: newerThanId, items: items);
  }

  void _addContiguousPage({
    required int anchorId,
    required List<MessageItem> items,
  }) {
    if (items.isEmpty) return;

    final anchorRangeIndex = _ranges.indexWhere(
      (range) => range.contains(anchorId),
    );
    if (anchorRangeIndex < 0) {
      _insertRange(MessageRange(items));
      return;
    }

    final merged = MessageRange([
      ..._ranges[anchorRangeIndex].messages,
      ...items,
    ]);
    _ranges.removeAt(anchorRangeIndex);
    _insertRange(merged);
  }

  void _insertRange(MessageRange incoming) {
    if (incoming.messages.isEmpty) return;

    final overlapping = <int>[];
    for (var index = 0; index < _ranges.length; index++) {
      if (_ranges[index].overlaps(incoming)) {
        overlapping.add(index);
      }
    }

    if (overlapping.isNotEmpty) {
      for (final index in overlapping) {
        incoming.mergeWith(_ranges[index]);
      }
      for (var i = overlapping.length - 1; i >= 0; i--) {
        _ranges.removeAt(overlapping[i]);
      }
    }

    var insertAt = _ranges.length;
    for (var index = 0; index < _ranges.length; index++) {
      if (incoming.end >= _ranges[index].end) {
        insertAt = index;
        break;
      }
    }
    _ranges.insert(insertAt, incoming);
    _invalidateCache();
    notifyListeners();
  }

  void removeById(int id) {
    for (var index = 0; index < _ranges.length; index++) {
      final range = _ranges[index];
      final messageIndex = range.indexOf(id);
      if (messageIndex < 0) continue;

      range.messages.removeAt(messageIndex);
      if (range.messages.isEmpty) {
        _ranges.removeAt(index);
      }
      _invalidateCache();
      notifyListeners();
      return;
    }
  }

  void replaceWhere(bool Function(MessageItem) test, MessageItem replacement) {
    for (final range in _ranges) {
      final index = range.messages.indexWhere(test);
      if (index < 0) continue;
      range.messages[index] = replacement;
      range.messages.sort((a, b) => b.id.compareTo(a.id));
      _invalidateCache();
      notifyListeners();
      return;
    }
  }

  void removeWhere(bool Function(MessageItem) test) {
    var changed = false;
    for (var index = _ranges.length - 1; index >= 0; index--) {
      final range = _ranges[index];
      final originalLength = range.messages.length;
      range.messages.removeWhere(test);
      if (range.messages.length != originalLength) {
        changed = true;
      }
      if (range.messages.isEmpty) {
        _ranges.removeAt(index);
      }
    }
    if (!changed) return;
    _invalidateCache();
    notifyListeners();
  }

  bool contains(int messageId) => findRangeContaining(messageId) != null;

  MessageRange? findRangeContaining(int messageId) {
    for (final range in _ranges) {
      if (range.contains(messageId)) return range;
    }
    return null;
  }

  List<MessageItem> newest({required int limit}) {
    if (_ranges.isEmpty) return const [];
    final range = _ranges.first;
    return range.messages.take(limit).toList(growable: false);
  }

  int? findNthNewestId(int index) {
    if (index < 0) return null;

    var remaining = index;
    for (final range in _ranges) {
      if (remaining < range.messages.length) {
        return range.messages[remaining].id;
      }
      remaining -= range.messages.length;
    }
    return null;
  }

  int? findWindowIndex({
    required int anchorMessageId,
    required int targetMessageId,
    required int before,
    required int after,
  }) {
    final window = getWindowAround(
      anchorMessageId,
      before: before,
      after: after,
    );
    if (window.isEmpty) return null;
    final index = window.indexWhere((message) => message.id == targetMessageId);
    return index >= 0 ? index : null;
  }

  List<MessageItem> takeOlderAdjacent(int fromId, int limit) {
    final range = findRangeContaining(fromId);
    if (range == null) return const [];
    final index = range.indexOf(fromId);
    if (index < 0 || index + 1 >= range.messages.length) return const [];

    final endIndex = (index + 1 + limit).clamp(0, range.messages.length);
    return range.messages.sublist(index + 1, endIndex);
  }

  List<MessageItem> takeNewerAdjacent(int fromId, int limit) {
    final range = findRangeContaining(fromId);
    if (range == null) return const [];
    final index = range.indexOf(fromId);
    if (index <= 0) return const [];

    final startIndex = (index - limit).clamp(0, index);
    return range.messages.sublist(startIndex, index);
  }

  List<MessageItem> getWindowAround(
    int messageId, {
    required int before,
    required int after,
  }) {
    final range = findRangeContaining(messageId);
    if (range == null) return const [];

    final index = range.indexOf(messageId);
    if (index < 0) return const [];

    final startIndex = (index - after).clamp(0, index);
    final endIndex =
        (index + before + 1).clamp(index + 1, range.messages.length);
    return range.messages.sublist(startIndex, endIndex);
  }

  List<MessageItem> sliceInclusive({
    required int newestId,
    required int oldestId,
  }) {
    final range = findRangeContaining(newestId);
    if (range == null || !range.contains(oldestId)) return const [];

    final newestIndex = range.indexOf(newestId);
    final oldestIndex = range.indexOf(oldestId);
    if (newestIndex < 0 || oldestIndex < 0 || newestIndex > oldestIndex) {
      return const [];
    }

    return range.messages.sublist(newestIndex, oldestIndex + 1);
  }

  int? findIndexInSlice({
    required int newestId,
    required int oldestId,
    required int messageId,
  }) {
    final slice = sliceInclusive(newestId: newestId, oldestId: oldestId);
    if (slice.isEmpty) return null;
    final index = slice.indexWhere((message) => message.id == messageId);
    return index >= 0 ? index : null;
  }

  bool get isEmpty =>
      _ranges.isEmpty || _ranges.every((range) => range.messages.isEmpty);
  bool get isNotEmpty => !isEmpty;

  int? get newestId => _ranges.isNotEmpty ? _ranges.first.end : null;
  int? get oldestId => _ranges.isNotEmpty ? _ranges.last.start : null;
}
