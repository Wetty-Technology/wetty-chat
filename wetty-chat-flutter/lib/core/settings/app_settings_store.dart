import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage {
  system('system'),
  english('english'),
  chinese('chinese');

  const AppLanguage(this.storageValue);

  final String storageValue;

  static AppLanguage fromStorage(String? value) {
    return AppLanguage.values.firstWhere(
      (language) => language.storageValue == value,
      orElse: () => AppLanguage.system,
    );
  }
}

class AppSettingsStore extends ChangeNotifier {
  AppSettingsStore._();
  static final AppSettingsStore instance = AppSettingsStore._();

  static const String _chatFontScaleKey = 'chat_font_scale';
  static const String _languageKey = 'app_language';
  static const double minChatFontScale = 0.85;
  static const double maxChatFontScale = 1.3;
  static const int chatFontScaleSteps = 5;

  late SharedPreferences _prefs;
  double _chatFontScale = 1.0;
  AppLanguage _language = AppLanguage.system;

  double get chatFontScale => _chatFontScale;
  AppLanguage get language => _language;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final stored = _prefs.getDouble(_chatFontScaleKey);
    _chatFontScale = _snapChatFontScale(
      (stored ?? 1.0).clamp(minChatFontScale, maxChatFontScale),
    );
    _language = AppLanguage.fromStorage(_prefs.getString(_languageKey));
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

  void setLanguage(AppLanguage language) {
    if (language == _language) return;
    _language = language;
    notifyListeners();
    _prefs.setString(_languageKey, _language.storageValue);
  }

  static double _snapChatFontScale(double value) {
    if (chatFontScaleSteps <= 1) return value;
    final step =
        (maxChatFontScale - minChatFontScale) / (chatFontScaleSteps - 1);
    final idx = ((value - minChatFontScale) / step).round();
    final clampedIdx = idx.clamp(0, chatFontScaleSteps - 1);
    return minChatFontScale + step * clampedIdx;
  }
}
