import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';

enum AppLanguage {
  system('system'),
  english('english'),
  chineseCN('chinese_cn'),
  chineseTW('chinese_tw');

  const AppLanguage(this.storageValue);

  final String storageValue;

  static AppLanguage fromStorage(String? value) {
    // Migrate old 'chinese' value to 'chinese_cn'
    if (value == 'chinese') return AppLanguage.chineseCN;
    return AppLanguage.values.firstWhere(
      (language) => language.storageValue == value,
      orElse: () => AppLanguage.system,
    );
  }

  /// Returns the locale for this language setting, or null for system default.
  Locale? toLocale() {
    return switch (this) {
      AppLanguage.system => null,
      AppLanguage.english => const Locale('en'),
      AppLanguage.chineseCN => const Locale('zh', 'CN'),
      AppLanguage.chineseTW => const Locale('zh', 'TW'),
    };
  }
}

extension AppLanguageDisplayName on AppLanguage {
  String displayName(AppLocalizations l10n) => switch (this) {
    AppLanguage.system => l10n.languageSystem,
    AppLanguage.english => l10n.languageEnglish,
    AppLanguage.chineseCN => l10n.languageChineseCN,
    AppLanguage.chineseTW => l10n.languageChineseTW,
  };
}

class AppSettingsStore extends ChangeNotifier {
  AppSettingsStore._();
  static final AppSettingsStore instance = AppSettingsStore._();

  static const String _chatMessageFontSizeKey = 'chat_message_font_size';
  static const String _languageKey = 'app_language';
  static const double minChatMessageFontSize = 14;
  static const double maxChatMessageFontSize = 18;
  static const int chatMessageFontSizeSteps = 5;
  static const double defaultChatMessageFontSize = 16;

  late SharedPreferences _prefs;
  double _chatMessageFontSize = defaultChatMessageFontSize;
  AppLanguage _language = AppLanguage.system;

  double get chatMessageFontSize => _chatMessageFontSize;
  AppLanguage get language => _language;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final stored = _prefs.getDouble(_chatMessageFontSizeKey);
    _chatMessageFontSize = _snapChatMessageFontSize(
      (stored ?? defaultChatMessageFontSize).clamp(
        minChatMessageFontSize,
        maxChatMessageFontSize,
      ),
    );
    _language = AppLanguage.fromStorage(_prefs.getString(_languageKey));
  }

  void setChatMessageFontSize(double value) {
    final next = _snapChatMessageFontSize(
      value.clamp(minChatMessageFontSize, maxChatMessageFontSize),
    );
    if (next == _chatMessageFontSize) return;
    _chatMessageFontSize = next;
    notifyListeners();
    _prefs.setDouble(_chatMessageFontSizeKey, _chatMessageFontSize);
  }

  void setLanguage(AppLanguage language) {
    if (language == _language) return;
    _language = language;
    notifyListeners();
    _prefs.setString(_languageKey, _language.storageValue);
  }

  static double _snapChatMessageFontSize(double value) {
    if (chatMessageFontSizeSteps <= 1) return value;
    final step =
        (maxChatMessageFontSize - minChatMessageFontSize) /
        (chatMessageFontSizeSteps - 1);
    final idx = ((value - minChatMessageFontSize) / step).round();
    final clampedIdx = idx.clamp(0, chatMessageFontSizeSteps - 1);
    return minChatMessageFontSize + step * clampedIdx;
  }
}
