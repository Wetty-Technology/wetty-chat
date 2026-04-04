import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DevSessionStore extends ChangeNotifier {
  DevSessionStore._();

  static final DevSessionStore instance = DevSessionStore._();

  static const int defaultUserId = 1;
  static const String _userIdStorageKey = 'dev_session_user_id';

  SharedPreferences? _prefs;
  int _currentUserId = defaultUserId;

  int get currentUserId => _currentUserId;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _currentUserId = _prefs?.getInt(_userIdStorageKey) ?? defaultUserId;
  }

  Future<void> setCurrentUserId(int userId) async {
    if (userId == _currentUserId) {
      return;
    }
    _currentUserId = userId;
    notifyListeners();
    await _prefs?.setInt(_userIdStorageKey, _currentUserId);
  }

  Future<void> resetToDefault() async {
    if (_currentUserId == defaultUserId) {
      await _prefs?.remove(_userIdStorageKey);
      return;
    }
    _currentUserId = defaultUserId;
    notifyListeners();
    await _prefs?.remove(_userIdStorageKey);
  }
}
