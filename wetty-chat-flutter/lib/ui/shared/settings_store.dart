import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsStore extends ChangeNotifier {
  SettingsStore._();
  static final SettingsStore instance = SettingsStore._();

  static const String _chatFontScaleKey = 'chat_font_scale';
  static const double minChatFontScale = 0.85;
  static const double maxChatFontScale = 1.3;
  static const int chatFontScaleSteps = 5;

  late SharedPreferences _prefs;
  double _chatFontScale = 1.0;

  double get chatFontScale => _chatFontScale;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final stored = _prefs.getDouble(_chatFontScaleKey);
    _chatFontScale = _snapChatFontScale((stored ?? 1.0).clamp(
      minChatFontScale,
      maxChatFontScale,
    ));
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

  static double _snapChatFontScale(double value) {
    if (chatFontScaleSteps <= 1) return value;
    final step = (maxChatFontScale - minChatFontScale) /
        (chatFontScaleSteps - 1);
    final idx = ((value - minChatFontScale) / step).round();
    final clampedIdx = idx.clamp(0, chatFontScaleSteps - 1);
    return minChatFontScale + step * clampedIdx;
  }
}
