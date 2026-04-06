import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/conversation_scope.dart';

/// Stores conversation drafts in memory for the current app session.
class ConversationDraftStore {
  static final Map<String, String> _cache = <String, String>{};

  String? getDraft(ConversationScope scope) => _cache[scope.storageKey];

  Future<void> setDraft(ConversationScope scope, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      await clearDraft(scope);
      return;
    }
    _cache[scope.storageKey] = trimmed;
  }

  Future<void> clearDraft(ConversationScope scope) async {
    _cache.remove(scope.storageKey);
  }
}

final conversationDraftProvider = Provider<ConversationDraftStore>((ref) {
  return ConversationDraftStore();
});
