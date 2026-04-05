import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import '../providers/shared_preferences_provider.dart';

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

typedef AppSettingsState = ({double fontSize, AppLanguage language});

class AppSettingsNotifier extends Notifier<AppSettingsState> {
  static const String _chatMessageFontSizeKey = 'chat_message_font_size';
  static const String _languageKey = 'app_language';
  static const double minChatMessageFontSize = 14;
  static const double maxChatMessageFontSize = 18;
  static const int chatMessageFontSizeSteps = 5;
  static const double defaultChatMessageFontSize = 16;

  late SharedPreferences _prefs;

  @override
  AppSettingsState build() {
    _prefs = ref.read(sharedPreferencesProvider);
    final stored = _prefs.getDouble(_chatMessageFontSizeKey);
    final fontSize = _snapChatMessageFontSize(
      (stored ?? defaultChatMessageFontSize).clamp(
        minChatMessageFontSize,
        maxChatMessageFontSize,
      ),
    );
    final language = AppLanguage.fromStorage(_prefs.getString(_languageKey));
    return (fontSize: fontSize, language: language);
  }

  void setChatMessageFontSize(double value) {
    final next = _snapChatMessageFontSize(
      value.clamp(minChatMessageFontSize, maxChatMessageFontSize),
    );
    if (next == state.fontSize) return;
    state = (fontSize: next, language: state.language);
    _prefs.setDouble(_chatMessageFontSizeKey, next);
  }

  void setLanguage(AppLanguage language) {
    if (language == state.language) return;
    state = (fontSize: state.fontSize, language: language);
    _prefs.setString(_languageKey, language.storageValue);
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

final appSettingsProvider =
    NotifierProvider<AppSettingsNotifier, AppSettingsState>(
      AppSettingsNotifier.new,
    );
