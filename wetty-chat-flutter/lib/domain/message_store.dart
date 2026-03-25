import '../data/models/message_models.dart';

int _safeNumericId(String id) {
  return int.tryParse(id) ?? 0;
}

class MessageStore {
  final List<MessageItem> _messages = [];

  List<MessageItem> get messages => List.unmodifiable(_messages);

  static int compareMessageOrder(MessageItem left, MessageItem right) {
    final leftTime = DateTime.tryParse(left.createdAt);
    final rightTime = DateTime.tryParse(right.createdAt);
    if (leftTime != null && rightTime != null) {
      final timeComparison = leftTime.compareTo(rightTime);
      if (timeComparison != 0) {
        return timeComparison;
      }
    }
    return _safeNumericId(left.id).compareTo(_safeNumericId(right.id));
  }

  void addMessages(List<MessageItem> items) {
    if (items.isEmpty) return;
    for (final item in items) {
      _insertOrReplace(item);
    }
    _messages.sort(compareMessageOrder);
  }

  List<MessageItem> buildDisplayItems() {
    return List.unmodifiable(_messages);
  }

  void clear() {
    _messages.clear();
  }

  void removeById(String id) {
    _messages.removeWhere((m) => m.id == id);
  }

  void replaceWhere(bool Function(MessageItem) test, MessageItem replacement) {
    final idx = _messages.indexWhere(test);
    if (idx >= 0) {
      _messages[idx] = replacement;
      _messages.sort(compareMessageOrder);
    }
  }

  void removeWhere(bool Function(MessageItem) test) {
    _messages.removeWhere(test);
  }

  void upsert(MessageItem item) {
    _insertOrReplace(item);
    _messages.sort(compareMessageOrder);
  }

  MessageItem? findById(String id) {
    for (final message in _messages) {
      if (message.id == id) {
        return message;
      }
    }
    return null;
  }

  bool get isEmpty => _messages.isEmpty;
  bool get isNotEmpty => !isEmpty;
  String? get oldestId => _messages.isNotEmpty ? _messages.first.id : null;
  String? get newestId => _messages.isNotEmpty ? _messages.last.id : null;

  void _insertOrReplace(MessageItem item) {
    final idx = _messages.indexWhere(
      (current) =>
          current.id == item.id ||
          (item.clientGeneratedId.isNotEmpty &&
              current.clientGeneratedId == item.clientGeneratedId),
    );
    if (idx >= 0) {
      _messages[idx] = item;
      return;
    }
    _messages.add(item);
  }
}
