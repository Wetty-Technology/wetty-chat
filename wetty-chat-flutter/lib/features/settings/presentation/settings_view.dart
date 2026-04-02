import 'package:flutter/cupertino.dart';

import '../../../app/presentation/root_navigation.dart';
import '../../../app/theme/style_config.dart';
import '../../../core/settings/app_settings_store.dart';
import '../../../features/auth/application/auth_store.dart';
import 'font_size_settings_view.dart';
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

  String _languageLabel(AppLanguage language) {
    switch (language) {
      case AppLanguage.system:
        return 'System';
      case AppLanguage.english:
        return 'English';
      case AppLanguage.chinese:
        return 'Chinese';
    }
  }

  Future<void> _showLanguagePicker() async {
    final currentLanguage = AppSettingsStore.instance.language;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: Text(
          'Language',
          style: appTextStyle(context, fontSize: AppFontSizes.body),
        ),
        actions: [
          for (final language in AppLanguage.values)
            CupertinoActionSheetAction(
              isDefaultAction: language == currentLanguage,
              onPressed: () {
                AppSettingsStore.instance.setLanguage(language);
                Navigator.of(context).pop();
              },
              child: Text(_languageLabel(language)),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  List<SettingsSectionData> _sections(AppLanguage language) {
    return [
      SettingsSectionData(
        title: 'General',
        items: [
          SettingsItemData(
            title: 'Language',
            icon: CupertinoIcons.globe,
            iconColor: const Color(0xFF3A7DFF),
            trailingText: _languageLabel(language),
            trailingTextSize: AppFontSizes.body,
            titleFontSize: AppFontSizes.body,
            titleFontWeight: FontWeight.w500,
            onTap: _showLanguagePicker,
          ),
          SettingsItemData(
            title: 'Text Size',
            icon: CupertinoIcons.textformat_size,
            iconColor: const Color(0xFF34A853),
            titleFontSize: AppFontSizes.body,
            titleFontWeight: FontWeight.w500,
            onTap: () => _openPage(const FontSizeSettingsPage()),
          ),
        ],
      ),
      SettingsSectionData(
        title: 'User',
        items: [
          SettingsItemData(
            title: 'Profile',
            icon: CupertinoIcons.person_crop_circle,
            iconColor: const Color(0xFF34AADC),
            titleFontSize: AppFontSizes.body,
            titleFontWeight: FontWeight.w500,
            onTap: () => _openPage(const ProfileSettingsPage()),
          ),
        ],
      ),
      SettingsSectionData(
        title: 'Notifications',
        items: [
          SettingsItemData(
            title: 'Notifications',
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
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: const CupertinoNavigationBar(middle: Text('Settings')),
      child: SafeArea(
        child: AnimatedBuilder(
          animation: AppSettingsStore.instance,
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
                SettingsSectionCard(
                  section: SettingsSectionData(
                    title: '',
                    items: [
                      SettingsItemData(
                        title: 'Log Out',
                        icon: CupertinoIcons.square_arrow_right,
                        iconColor: const Color(0xFFFF3B30),
                        titleFontSize: AppFontSizes.body,
                        titleFontWeight: FontWeight.w500,
                        onTap: _confirmLogout,
                        isDestructive: true,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('退出登录？', style: appTextStyle(context)),
        content: Text('这会清除当前设备保存的登录状态。', style: appTextStyle(context)),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: Text('取消', style: appTextStyle(context)),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: Text('退出登录', style: appTextStyle(context)),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await AuthStore.instance.clearToken();
    }
  }
}
