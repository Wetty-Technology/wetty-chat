import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsStore extends ChangeNotifier {
  SettingsStore._();
  static final SettingsStore instance = SettingsStore._();

  static const String _chatFontScaleKey = 'chat_font_scale';
  static const String _darkModeEnabledKey = 'dark_mode_enabled';
  // Kept for migration from the old chat theme color feature.
  static const String _legacyChatThemeColorKey = 'chat_theme_color';
  static const double minChatFontScale = 0.85;
  static const double maxChatFontScale = 1.3;
  static const int chatFontScaleSteps = 5;
  static const int _lightChatBackgroundColorValue = 0xFFECE5DD;
  static const int _darkChatBackgroundColorValue = 0xFF334155;
  static const int _legacyDarkChatThemeColorValue = _darkChatBackgroundColorValue;
  static const int _chatAccentColorValue = 0xFF3A7DFF;

  late SharedPreferences _prefs;
  double _chatFontScale = 1.0;
  bool _isDarkModeEnabled = false;

  double get chatFontScale => _chatFontScale;
  bool get isDarkModeEnabled => _isDarkModeEnabled;
  Brightness get appBrightness =>
      _isDarkModeEnabled ? Brightness.dark : Brightness.light;
  Color get chatBackgroundColor => Color(
    _isDarkModeEnabled
        ? _darkChatBackgroundColorValue
        : _lightChatBackgroundColorValue,
  );
  Color get chatAccentColor => const Color(_chatAccentColorValue);

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final stored = _prefs.getDouble(_chatFontScaleKey);
    _chatFontScale = _snapChatFontScale((stored ?? 1.0).clamp(
      minChatFontScale,
      maxChatFontScale,
    ));
    final storedDarkMode = _prefs.getBool(_darkModeEnabledKey);
    if (storedDarkMode != null) {
      _isDarkModeEnabled = storedDarkMode;
      return;
    }

    final legacyColor = _prefs.getInt(_legacyChatThemeColorKey);
    _isDarkModeEnabled = legacyColor == _legacyDarkChatThemeColorValue;
  }

  void setChatFontScale(double value) {
    final next = _snapChatFontScale(
      value.clamp(minChatFontScale, maxChatFontScale),
    );
    if (next == _chatFontScale) return;
    _chatFontScale = next;
    notifyListeners();
    _prefs.setDouble(_chatFontScaleKey, _chatFontScale);
  }

  void setDarkModeEnabled(bool value) {
    if (value == _isDarkModeEnabled) return;
    _isDarkModeEnabled = value;
    notifyListeners();
    _prefs.setBool(_darkModeEnabledKey, _isDarkModeEnabled);
  }

  static double _snapChatFontScale(double value) {
    if (chatFontScaleSteps <= 1) return value;
    final step = (maxChatFontScale - minChatFontScale) /
        (chatFontScaleSteps - 1);
    final idx = ((value - minChatFontScale) / step).round();
    final clampedIdx = idx.clamp(0, chatFontScaleSteps - 1);
    return minChatFontScale + step * clampedIdx;
  }
}
