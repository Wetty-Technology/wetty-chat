import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/providers/shared_preferences_provider.dart';

/// Persists draft messages per chat using SharedPreferences.
class ChatDraftStore {
  ChatDraftStore(this._prefs) {
    _loadCache();
  }

  static const String _prefix = 'draft_';

  final SharedPreferences _prefs;
  final Map<String, String> _cache = {};

  void _loadCache() {
    for (final key in _prefs.getKeys()) {
      if (key.startsWith(_prefix)) {
        final chatId = key.substring(_prefix.length);
        final value = _prefs.getString(key);
        if (value != null && value.isNotEmpty) {
          _cache[chatId] = value;
        }
      }
    }
  }

  /// Returns the draft text for [chatId], or null if none.
  String? getDraft(String chatId) => _cache[chatId];

  /// Saves a draft for [chatId]. Pass empty/null to clear.
  Future<void> setDraft(String chatId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return clearDraft(chatId);
    }
    _cache[chatId] = trimmed;
    await _prefs.setString('$_prefix$chatId', trimmed);
  }

  /// Removes the draft for [chatId].
  Future<void> clearDraft(String chatId) async {
    _cache.remove(chatId);
    await _prefs.remove('$_prefix$chatId');
  }
}

final chatDraftProvider = Provider<ChatDraftStore>((ref) {
  return ChatDraftStore(ref.read(sharedPreferencesProvider));
});
