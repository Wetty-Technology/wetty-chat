import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/conversation_identity.dart';

enum ConversationLocalMutationKind { inserted, updated, removed }

class ConversationLocalMutation {
  const ConversationLocalMutation({required this.identity, required this.kind});

  final ConversationIdentity identity;
  final ConversationLocalMutationKind kind;
}

typedef ConversationLocalMutationListener =
    void Function(ConversationLocalMutation mutation);

/// Broadcasts local conversation mutations so active timelines can rebuild
/// immediately without waiting for transport-level acknowledgements.
class ConversationLocalMutationRegistry {
  final Map<Object, ConversationLocalMutationListener> _listeners =
      <Object, ConversationLocalMutationListener>{};

  Object addListener(ConversationLocalMutationListener listener) {
    final token = Object();
    _listeners[token] = listener;
    return token;
  }

  void removeListener(Object token) {
    _listeners.remove(token);
  }

  void dispatch(ConversationLocalMutation mutation) {
    for (final listener in _listeners.values.toList(growable: false)) {
      listener(mutation);
    }
  }
}

final conversationLocalMutationRegistryProvider =
    Provider<ConversationLocalMutationRegistry>((ref) {
      return ConversationLocalMutationRegistry();
    });
