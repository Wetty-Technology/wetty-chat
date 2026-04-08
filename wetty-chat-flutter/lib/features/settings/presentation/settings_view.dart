import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';

import '../../../app/routing/route_names.dart';
import '../../../app/theme/style_config.dart';
import '../../../core/session/dev_session_store.dart';
import '../../../core/settings/app_settings_store.dart';
import 'settings_components.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  List<SettingsSectionData> _sections(
    BuildContext context,
    AppLanguage language,
    AuthSessionState session,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final sessionLabel = switch (session.mode) {
      AuthSessionMode.jwt => 'JWT',
      AuthSessionMode.devHeader => 'UID ${session.currentUserId}',
      AuthSessionMode.none => 'No session',
    };
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
            onTap: () => context.push(AppRoutes.language),
          ),
          SettingsItemData(
            title: l10n.settingsTextSize,
            icon: CupertinoIcons.textformat_size,
            iconColor: const Color(0xFF34A853),
            titleFontSize: AppFontSizes.body,
            titleFontWeight: FontWeight.w500,
            onTap: () => context.push(AppRoutes.fontSize),
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
            onTap: () => context.push(AppRoutes.profile),
          ),
          SettingsItemData(
            title: 'Developer Session',
            icon: CupertinoIcons.person_crop_square,
            iconColor: const Color(0xFF8E44AD),
            trailingText: sessionLabel,
            trailingTextSize: AppFontSizes.body,
            titleFontSize: AppFontSizes.body,
            titleFontWeight: FontWeight.w500,
            onTap: () => context.push(AppRoutes.devSession),
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
            onTap: () => context.push(AppRoutes.notifications),
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(appSettingsProvider);
    final session = ref.watch(authSessionProvider);
    final sections = _sections(context, settings.language, session);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text(l10n.tabSettings)),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            for (final section in sections) ...[
              SettingsSectionCard(section: section),
              const SizedBox(height: 16),
            ],
            const SizedBox(height: 54),
          ],
        ),
      ),
    );
  }
}
