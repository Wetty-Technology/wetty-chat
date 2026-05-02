import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/style_config.dart';
import '../../../core/session/dev_session_store.dart';
import '../../../core/settings/app_settings_store.dart';
import '../../../l10n/app_localizations.dart';
import 'settings_components.dart';

class SettingsContent extends ConsumerWidget {
  const SettingsContent({
    super.key,
    required this.onOpenStickerPacks,
    required this.onOpenLanguage,
    required this.onOpenFontSize,
    required this.onOpenCache,
    required this.onOpenProfile,
    required this.onOpenDevSession,
    required this.onOpenNotifications,
    this.leading,
    this.automaticallyImplyLeading = true,
  });

  final VoidCallback onOpenStickerPacks;
  final VoidCallback onOpenLanguage;
  final VoidCallback onOpenFontSize;
  final VoidCallback onOpenCache;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenDevSession;
  final VoidCallback onOpenNotifications;
  final Widget? leading;
  final bool automaticallyImplyLeading;

  List<SettingsSectionData> _sections(
    BuildContext context,
    WidgetRef ref,
    AppSettingsState settings,
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
        title: l10n.settingsChat,
        items: [
          SettingsItemData(
            title: l10n.settingsShowAllTab,
            icon: CupertinoIcons.list_bullet,
            iconColor: const Color(0xFF5856D6),
            titleFontSize: AppFontSizes.body,
            titleFontWeight: AppFontWeights.medium,
            showChevron: false,
            trailingWidget: CupertinoSwitch(
              value: settings.showAllTab,
              onChanged: (value) {
                ref.read(appSettingsProvider.notifier).setShowAllTab(value);
              },
            ),
            onTap: () {
              ref
                  .read(appSettingsProvider.notifier)
                  .setShowAllTab(!settings.showAllTab);
            },
          ),
          SettingsItemData(
            title: 'Sticker Packs',
            icon: CupertinoIcons.smiley,
            iconColor: const Color(0xFFFF6482),
            titleFontSize: AppFontSizes.body,
            titleFontWeight: AppFontWeights.medium,
            onTap: onOpenStickerPacks,
          ),
        ],
      ),
      SettingsSectionData(
        title: l10n.settingsGeneral,
        items: [
          SettingsItemData(
            title: l10n.settingsLanguage,
            icon: CupertinoIcons.globe,
            iconColor: const Color(0xFF3A7DFF),
            trailingText: settings.language.displayName(l10n),
            trailingTextSize: AppFontSizes.body,
            titleFontSize: AppFontSizes.body,
            titleFontWeight: AppFontWeights.medium,
            onTap: onOpenLanguage,
          ),
          SettingsItemData(
            title: l10n.settingsTextSize,
            icon: CupertinoIcons.textformat_size,
            iconColor: const Color(0xFF34A853),
            titleFontSize: AppFontSizes.body,
            titleFontWeight: AppFontWeights.medium,
            onTap: onOpenFontSize,
          ),
          SettingsItemData(
            title: l10n.settingsCache,
            icon: CupertinoIcons.tray_full,
            iconColor: const Color(0xFF5E5CE6),
            titleFontSize: AppFontSizes.body,
            titleFontWeight: AppFontWeights.medium,
            onTap: onOpenCache,
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
            titleFontWeight: AppFontWeights.medium,
            onTap: onOpenProfile,
          ),
          SettingsItemData(
            title: 'Developer Session',
            icon: CupertinoIcons.person_crop_square,
            iconColor: const Color(0xFF8E44AD),
            trailingText: sessionLabel,
            trailingTextSize: AppFontSizes.body,
            titleFontSize: AppFontSizes.body,
            titleFontWeight: AppFontWeights.medium,
            onTap: onOpenDevSession,
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
            titleFontWeight: AppFontWeights.medium,
            onTap: onOpenNotifications,
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
    final sections = _sections(context, ref, settings, session);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        automaticallyImplyLeading: automaticallyImplyLeading,
        leading: leading,
        middle: Text(l10n.tabSettings),
      ),
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
