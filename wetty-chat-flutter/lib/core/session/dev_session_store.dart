import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/shared_preferences_provider.dart';

class DevSessionNotifier extends Notifier<int> {
  static const int defaultUserId = 1;
  static const String _userIdStorageKey = 'dev_session_user_id';

  late SharedPreferences _prefs;

  @override
  int build() {
    _prefs = ref.read(sharedPreferencesProvider);
    return _prefs.getInt(_userIdStorageKey) ?? defaultUserId;
  }

  Future<void> setCurrentUserId(int userId) async {
    if (userId == state) return;
    state = userId;
    await _prefs.setInt(_userIdStorageKey, userId);
  }

  Future<void> resetToDefault() async {
    await _prefs.remove(_userIdStorageKey);
    if (state != defaultUserId) {
      state = defaultUserId;
    }
  }
}

final devSessionProvider = NotifierProvider<DevSessionNotifier, int>(
  DevSessionNotifier.new,
);
