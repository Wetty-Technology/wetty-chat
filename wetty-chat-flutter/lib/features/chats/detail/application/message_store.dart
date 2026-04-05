import '../../models/message_models.dart';

/// A contiguous block of messages sorted descending by snowflake ID.
class MessageRange {
  final List<MessageItem> messages;

  MessageRange(List<MessageItem> items) : messages = List.of(items) {
    assert(_isSortedDescending(messages));
  }

  // TODO: this is a test only function
  static bool _isSortedDescending(List<MessageItem> items) {
    for (var i = 1; i < items.length; i++) {
      if (items[i - 1].id < items[i].id) {
        return false;
      }
    }
    return true;
  }

  int indexOf(int messageId) {
    return messages.indexWhere((message) => message.id == messageId);
  }

  int get newestId => messages.first.id;
  int get oldestId => messages.last.id;

  bool containsId(int messageId) => indexOf(messageId) >= 0;

  bool overlapsById(MessageRange other) {
    final smaller = messages.length <= other.messages.length
        ? messages
        : other.messages;
    final largerIds = (identical(smaller, messages) ? other.messages : messages)
        .map((message) => message.id)
        .toSet();
    return smaller.any((message) => largerIds.contains(message.id));
  }

  bool extendsLiveEdgeOf(MessageRange other) {
    return messages.isNotEmpty &&
        other.messages.isNotEmpty &&
        oldestId > other.newestId;
  }

  void mergeWith(MessageRange other) {
    final current = List<MessageItem>.of(messages, growable: false);
    messages
      ..clear()
      ..addAll(_mergeSortedMessages(current, other.messages));
  }

  static List<MessageItem> _mergeSortedMessages(
    List<MessageItem> left,
    List<MessageItem> right,
  ) {
    final merged = <MessageItem>[];
    var leftIndex = 0;
    var rightIndex = 0;

    while (leftIndex < left.length && rightIndex < right.length) {
      final leftMessage = left[leftIndex];
      final rightMessage = right[rightIndex];

      if (leftMessage.id == rightMessage.id) {
        merged.add(rightMessage);
        leftIndex++;
        rightIndex++;
        continue;
      }

      if (leftMessage.id > rightMessage.id) {
        merged.add(leftMessage);
        leftIndex++;
      } else {
        merged.add(rightMessage);
        rightIndex++;
      }
    }

    if (leftIndex < left.length) {
      merged.addAll(left.sublist(leftIndex));
    }
    if (rightIndex < right.length) {
      merged.addAll(right.sublist(rightIndex));
    }

    return merged;
  }
}

class MessageStore {
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

  List<MessageItem> buildDisplayItems() => List.unmodifiable(displayItems);

  void _invalidateCache() {
    _cachedItems = null;
  }

  void clear() {
    _ranges.clear();
    _invalidateCache();
  }

  void addMessages(List<MessageItem> items) {
    _insertRange(MessageRange(items));
  }

  void addOlderPage({
    required int olderThanId,
    required List<MessageItem> items,
  }) {
    _addContiguousPage(anchorId: olderThanId, items: items);
  }

  void addNewerPage({
    required int newerThanId,
    required List<MessageItem> items,
  }) {
    _addContiguousPage(anchorId: newerThanId, items: items);
  }

  void _addContiguousPage({
    required int anchorId,
    required List<MessageItem> items,
  }) {
    if (items.isEmpty) return;

    final anchorRangeIndex = _ranges.indexWhere(
      (range) => range.containsId(anchorId),
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
      if (_ranges[index].overlapsById(incoming)) {
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

    if (_ranges.isNotEmpty && incoming.extendsLiveEdgeOf(_ranges.first)) {
      incoming.mergeWith(_ranges.removeAt(0));
    }

    var insertAt = _ranges.length;
    for (var index = 0; index < _ranges.length; index++) {
      if (incoming.newestId >= _ranges[index].newestId) {
        insertAt = index;
        break;
      }
    }
    _ranges.insert(insertAt, incoming);
    _coalesceOverlappingRanges();
    _invalidateCache();
  }

  void _coalesceOverlappingRanges() {
    var index = 0;
    while (index < _ranges.length) {
      var mergedAny = false;
      var otherIndex = index + 1;
      while (otherIndex < _ranges.length) {
        if (_ranges[index].overlapsById(_ranges[otherIndex])) {
          _ranges[index].mergeWith(_ranges.removeAt(otherIndex));
          mergedAny = true;
          continue;
        }
        otherIndex++;
      }
      if (!mergedAny) {
        index++;
      }
    }
    _ranges.sort((a, b) => b.newestId.compareTo(a.newestId));
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
  }

  bool contains(int messageId) => findRangeContaining(messageId) != null;

  MessageRange? findRangeContaining(int messageId) {
    for (final range in _ranges) {
      if (range.containsId(messageId)) return range;
    }
    return null;
  }

  List<MessageItem> newest({required int limit}) {
    if (_ranges.isEmpty) return const [];

    final items = <MessageItem>[];
    for (final range in _ranges) {
      for (final message in range.messages) {
        items.add(message);
        if (items.length == limit) {
          return List.unmodifiable(items);
        }
      }
    }
    return List.unmodifiable(items);
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
    final endIndex = (index + before + 1).clamp(
      index + 1,
      range.messages.length,
    );
    return range.messages.sublist(startIndex, endIndex);
  }

  List<MessageItem> sliceInclusive({
    required int newestId,
    required int oldestId,
  }) {
    final range = findRangeContaining(newestId);
    if (range == null || !range.containsId(oldestId)) return const [];

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

  int? get newestId => _ranges.isNotEmpty ? _ranges.first.newestId : null;
  int? get oldestId => _ranges.isNotEmpty ? _ranges.last.oldestId : null;
}
