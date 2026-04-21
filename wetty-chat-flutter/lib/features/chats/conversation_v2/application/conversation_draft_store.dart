import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/conversation_identity.dart';

/// Stores conversation drafts in memory for the current app session.
class ConversationDraftStore {
  static final Map<String, String> _cache = <String, String>{};

  String? getDraft(ConversationIdentity identity) =>
      _cache[_storageKey(identity)];

  Future<void> setDraft(ConversationIdentity identity, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      await clearDraft(identity);
      return;
    }
    _cache[_storageKey(identity)] = trimmed;
  }

  Future<void> clearDraft(ConversationIdentity identity) async {
    _cache.remove(_storageKey(identity));
  }

  String _storageKey(ConversationIdentity identity) {
    return identity.threadRootId == null
        ? identity.chatId
        : '${identity.chatId}::thread::${identity.threadRootId}';
  }
}

final conversationDraftProvider = Provider<ConversationDraftStore>((ref) {
  return ConversationDraftStore();
});
