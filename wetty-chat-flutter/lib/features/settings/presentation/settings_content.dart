import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/style_config.dart';
import '../../../core/session/dev_session_store.dart';
import '../../../l10n/app_localizations.dart';
import 'settings_components.dart';
import 'settings_profile_hero.dart';

class SettingsContent extends ConsumerWidget {
  const SettingsContent({
    super.key,
    required this.onOpenStickerPacks,
    required this.onOpenGeneral,
    required this.onOpenAppearance,
    required this.onOpenDevSession,
    required this.onOpenNotifications,
    this.leading,
    this.automaticallyImplyLeading = true,
  });

  final VoidCallback onOpenStickerPacks;
  final VoidCallback onOpenGeneral;
  final VoidCallback onOpenAppearance;
  final VoidCallback onOpenDevSession;
  final VoidCallback onOpenNotifications;
  final Widget? leading;
  final bool automaticallyImplyLeading;

  List<SettingsSectionData> _sections(
    BuildContext context,
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
        items: [
          SettingsItemData(
            title: l10n.settingsGeneral,
            icon: CupertinoIcons.gear_alt,
            iconColor: const Color(0xFF8E8E93),
            titleFontSize: AppFontSizes.body,
            titleFontWeight: AppFontWeights.medium,
            onTap: onOpenGeneral,
          ),
          SettingsItemData(
            title: l10n.settingsAppearance,
            icon: CupertinoIcons.textformat,
            iconColor: const Color(0xFF34A853),
            titleFontSize: AppFontSizes.body,
            titleFontWeight: AppFontWeights.medium,
            onTap: onOpenAppearance,
          ),
          SettingsItemData(
            title: l10n.settingsEmojisAndStickers,
            icon: CupertinoIcons.smiley,
            iconColor: const Color(0xFFFF6482),
            titleFontSize: AppFontSizes.body,
            titleFontWeight: AppFontWeights.medium,
            onTap: onOpenStickerPacks,
          ),
        ],
      ),
      SettingsSectionData(
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
      SettingsSectionData(
        items: [
          SettingsItemData(
            title: l10n.settingsDeveloperSession,
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
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final session = ref.watch(authSessionProvider);
    final sections = _sections(context, session);
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        automaticallyImplyLeading: automaticallyImplyLeading,
        leading: leading,
        middle: Text(l10n.tabSettings),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const SettingsProfileHero(),
            const SizedBox(height: 16),
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
