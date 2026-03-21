import 'package:shared_preferences/shared_preferences.dart';

/// Persists draft messages per chat using SharedPreferences.
/// Call [init] once at app startup before accessing drafts.
class DraftStore {
  DraftStore._();
  static final DraftStore instance = DraftStore._();

  static const String _prefix = 'draft_';

  late SharedPreferences _prefs;
  final Map<String, String> _cache = {};

  /// Initialise the store – call once in main() before runApp().
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    // Load all existing drafts into memory cache
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
