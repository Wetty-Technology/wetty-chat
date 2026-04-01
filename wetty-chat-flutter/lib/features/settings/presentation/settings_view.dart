import 'package:flutter/cupertino.dart';

import '../../../app/presentation/root_navigation.dart';
import '../../../app/theme/style_config.dart';
import '../../../features/auth/application/auth_store.dart';
import 'general_settings_view.dart';
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

  List<SettingsSectionData> _sections() {
    return [
      SettingsSectionData(
        title: 'General',
        items: [
          SettingsItemData(
            title: 'General',
            icon: CupertinoIcons.settings,
            iconColor: const Color(0xFF3A7DFF),
            onTap: () => _openPage(const GeneralSettingsPage()),
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
            onTap: () => _openPage(const NotificationSettingsPage()),
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final sections = _sections();

    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Settings'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            for (final section in sections) ...[
              SettingsSectionCard(section: section),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 24),
            SettingsSectionCard(
              section: SettingsSectionData(
                title: 'Account',
                items: [
                  SettingsItemData(
                    title: 'Log Out',
                    icon: CupertinoIcons.square_arrow_right,
                    iconColor: const Color(0xFFFF3B30),
                    onTap: _confirmLogout,
                    isDestructive: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
