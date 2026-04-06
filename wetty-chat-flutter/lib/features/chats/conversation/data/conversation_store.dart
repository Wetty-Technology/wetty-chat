import '../models/conversation_models.dart';

class ConversationStore {
  final Map<String, ConversationMessage> _messagesByKey = {};
  final Map<int, String> _serverKeyById = {};
  final Map<String, String> _clientGeneratedKeyById = {};
  final List<String> _orderedKeys = <String>[];

  List<ConversationMessage> get orderedMessages => _orderedKeys
      .map((key) => _messagesByKey[key])
      .whereType<ConversationMessage>()
      .toList(growable: false);

  bool get isEmpty => _orderedKeys.isEmpty;

  int? get newestServerId => orderedMessages
      .firstWhereOrNull((message) => message.serverId != null)
      ?.serverId;

  int? get oldestServerId => orderedMessages
      .lastWhereOrNull((message) => message.serverId != null)
      ?.serverId;

  ConversationMessage? messageByServerId(int messageId) {
    final key = _serverKeyById[messageId];
    return key == null ? null : _messagesByKey[key];
  }

  ConversationMessage? messageByClientGeneratedId(String clientGeneratedId) {
    final key = _clientGeneratedKeyById[clientGeneratedId];
    return key == null ? null : _messagesByKey[key];
  }

  void clear() {
    _messagesByKey.clear();
    _serverKeyById.clear();
    _clientGeneratedKeyById.clear();
    _orderedKeys.clear();
  }

  void mergeServerMessages(List<ConversationMessage> incoming) {
    for (final message in incoming) {
      mergeServerMessage(message);
    }
  }

  void mergeServerMessage(ConversationMessage incoming) {
    final replacement = incoming.copyWith(
      localId: null,
      deliveryState: ConversationDeliveryState.sent,
    );
    final clientKey = incoming.clientGeneratedId.isNotEmpty
        ? _clientGeneratedKeyById[incoming.clientGeneratedId]
        : null;
    final serverKey = incoming.serverId != null
        ? _serverKeyById[incoming.serverId!]
        : null;
    final existingKey = clientKey ?? serverKey;
    final nextKey = replacement.stableKey;

    if (existingKey != null && existingKey != nextKey) {
      final index = _orderedKeys.indexOf(existingKey);
      if (index >= 0) {
        _orderedKeys[index] = nextKey;
      }
      _messagesByKey.remove(existingKey);
    } else if (!_orderedKeys.contains(nextKey)) {
      _insertKey(nextKey, replacement);
    }

    _messagesByKey[nextKey] = replacement;
    if (replacement.serverId != null) {
      _serverKeyById[replacement.serverId!] = nextKey;
    }
    if (replacement.clientGeneratedId.isNotEmpty) {
      _clientGeneratedKeyById[replacement.clientGeneratedId] = nextKey;
    }
    _resort();
  }

  void insertOptimisticMessage(ConversationMessage message) {
    _messagesByKey[message.stableKey] = message;
    if (message.clientGeneratedId.isNotEmpty) {
      _clientGeneratedKeyById[message.clientGeneratedId] = message.stableKey;
    }
    if (!_orderedKeys.contains(message.stableKey)) {
      _insertKey(message.stableKey, message);
    }
    _resort();
  }

  void updateMessage(ConversationMessage message) {
    final existing = message.serverId != null
        ? messageByServerId(message.serverId!)
        : messageByClientGeneratedId(message.clientGeneratedId);
    final key = existing?.stableKey ?? message.stableKey;
    if (!_orderedKeys.contains(key)) {
      _orderedKeys.add(key);
    }
    _messagesByKey[key] = message.copyWith(
      localId: existing?.localId ?? message.localId,
    );
    if (message.serverId != null) {
      _serverKeyById[message.serverId!] = key;
    }
    if (message.clientGeneratedId.isNotEmpty) {
      _clientGeneratedKeyById[message.clientGeneratedId] = key;
    }
    _resort();
  }

  void tombstoneMessage(int messageId) {
    final existing = messageByServerId(messageId);
    if (existing == null) {
      return;
    }
    _messagesByKey[existing.stableKey] = existing.copyWith(
      isDeleted: true,
      message: null,
      deliveryState: ConversationDeliveryState.sent,
    );
  }

  List<ConversationMessage> latest({required int limit}) {
    return orderedMessages.take(limit).toList(growable: false);
  }

  List<ConversationMessage> around(
    int messageId, {
    required int before,
    required int after,
  }) {
    final anchorIndex = _orderedKeys.indexWhere((key) {
      final message = _messagesByKey[key];
      return message?.serverId == messageId;
    });
    if (anchorIndex < 0) {
      return const <ConversationMessage>[];
    }
    final start = (anchorIndex - after).clamp(0, anchorIndex);
    final end = (anchorIndex + before + 1).clamp(
      anchorIndex + 1,
      _orderedKeys.length,
    );
    return _orderedKeys
        .sublist(start, end)
        .map((key) => _messagesByKey[key]!)
        .toList(growable: false);
  }

  List<ConversationMessage> olderThan(int messageId, {required int limit}) {
    final anchorIndex = _orderedKeys.indexWhere((key) {
      final message = _messagesByKey[key];
      return message?.serverId == messageId;
    });
    if (anchorIndex < 0 || anchorIndex + 1 >= _orderedKeys.length) {
      return const <ConversationMessage>[];
    }
    final end = (anchorIndex + 1 + limit).clamp(
      anchorIndex + 1,
      _orderedKeys.length,
    );
    return _orderedKeys
        .sublist(anchorIndex + 1, end)
        .map((key) => _messagesByKey[key]!)
        .toList(growable: false);
  }

  List<ConversationMessage> newerThan(int messageId, {required int limit}) {
    final anchorIndex = _orderedKeys.indexWhere((key) {
      final message = _messagesByKey[key];
      return message?.serverId == messageId;
    });
    if (anchorIndex <= 0) {
      return const <ConversationMessage>[];
    }
    final start = (anchorIndex - limit).clamp(0, anchorIndex);
    return _orderedKeys
        .sublist(start, anchorIndex)
        .map((key) => _messagesByKey[key]!)
        .toList(growable: false);
  }

  int? firstNewerServerId(int messageId) {
    final newer = newerThan(messageId, limit: 1);
    return newer.isEmpty ? null : newer.last.serverId;
  }

  bool hasOlderAdjacent(int messageId) =>
      olderThan(messageId, limit: 1).isNotEmpty;

  bool hasNewerAdjacent(int messageId) =>
      newerThan(messageId, limit: 1).isNotEmpty;

  void _insertKey(String key, ConversationMessage message) {
    final insertAt = _orderedKeys.indexWhere((existingKey) {
      final existing = _messagesByKey[existingKey];
      if (existing == null) {
        return false;
      }
      return _compareMessages(message, existing) < 0;
    });
    if (insertAt < 0) {
      _orderedKeys.add(key);
    } else {
      _orderedKeys.insert(insertAt, key);
    }
  }

  void _resort() {
    _orderedKeys.sort((leftKey, rightKey) {
      final left = _messagesByKey[leftKey]!;
      final right = _messagesByKey[rightKey]!;
      return _compareMessages(left, right);
    });
  }

  int _compareMessages(ConversationMessage left, ConversationMessage right) {
    final leftServerId = left.serverId;
    final rightServerId = right.serverId;
    if (leftServerId != null && rightServerId != null) {
      return rightServerId.compareTo(leftServerId);
    }
    if (leftServerId != null) {
      return -1;
    }
    if (rightServerId != null) {
      return 1;
    }
    final leftTime = left.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final rightTime = right.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return rightTime.compareTo(leftTime);
  }
}

extension<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (final element in this) {
      if (test(element)) {
        return element;
      }
    }
    return null;
  }

  T? lastWhereOrNull(bool Function(T element) test) {
    final items = toList(growable: false);
    for (final element in items.reversed) {
      if (test(element)) {
        return element;
      }
    }
    return null;
  }
}
