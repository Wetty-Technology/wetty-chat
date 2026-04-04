import 'package:flutter/cupertino.dart';
import '../../../l10n/app_localizations.dart';

import '../../../app/presentation/root_navigation.dart';
import '../../../app/theme/style_config.dart';
import '../../../core/session/dev_session_store.dart';
import '../../../core/settings/app_settings_store.dart';
import 'dev_session_settings_view.dart';
import 'font_size_settings_view.dart';
import 'language_settings_view.dart';
import 'notification_settings_view.dart';
import 'profile_settings_view.dart';
import 'settings_components.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  void _openPage(Widget page) {
    pushRootCupertinoPage<void>(context, page);
  }

  List<SettingsSectionData> _sections(AppLanguage language) {
    final l10n = AppLocalizations.of(context)!;
    final currentUserId = DevSessionStore.instance.currentUserId;
    return [
      SettingsSectionData(
        title: l10n.settingsGeneral,
        items: [
          SettingsItemData(
            title: l10n.settingsLanguage,
            icon: CupertinoIcons.globe,
            iconColor: const Color(0xFF3A7DFF),
            trailingText: language.displayName(l10n),
            trailingTextSize: AppFontSizes.body,
            titleFontSize: AppFontSizes.body,
            titleFontWeight: FontWeight.w500,
            onTap: () => _openPage(const LanguageSettingsPage()),
          ),
          SettingsItemData(
            title: l10n.settingsTextSize,
            icon: CupertinoIcons.textformat_size,
            iconColor: const Color(0xFF34A853),
            titleFontSize: AppFontSizes.body,
            titleFontWeight: FontWeight.w500,
            onTap: () => _openPage(const FontSizeSettingsPage()),
          ),
        ],
      ),
      SettingsSectionData(
        title: l10n.settingsUser,
        items: [
          SettingsItemData(
            title: l10n.settingsProfile,
            icon: CupertinoIcons.person_crop_circle,
            iconColor: const Color(0xFF34AADC),
            titleFontSize: AppFontSizes.body,
            titleFontWeight: FontWeight.w500,
            onTap: () => _openPage(const ProfileSettingsPage()),
          ),
          SettingsItemData(
            title: 'Developer Session',
            icon: CupertinoIcons.person_crop_square,
            iconColor: const Color(0xFF8E44AD),
            trailingText: 'UID $currentUserId',
            trailingTextSize: AppFontSizes.body,
            titleFontSize: AppFontSizes.body,
            titleFontWeight: FontWeight.w500,
            onTap: () => _openPage(const DevSessionSettingsPage()),
          ),
        ],
      ),
      SettingsSectionData(
        title: l10n.settingsNotifications,
        items: [
          SettingsItemData(
            title: l10n.settingsNotifications,
            icon: CupertinoIcons.bell,
            iconColor: const Color(0xFFFF9500),
            titleFontSize: AppFontSizes.body,
            titleFontWeight: FontWeight.w500,
            onTap: () => _openPage(const NotificationSettingsPage()),
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(middle: Text(l10n.tabSettings)),
      child: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([
            AppSettingsStore.instance,
            DevSessionStore.instance,
          ]),
          builder: (context, _) {
            final sections = _sections(AppSettingsStore.instance.language);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                for (final section in sections) ...[
                  SettingsSectionCard(section: section),
                  const SizedBox(height: 16),
                ],
                const SizedBox(height: 54),
              ],
            );
          },
        ),
      ),
    );
  }
}
