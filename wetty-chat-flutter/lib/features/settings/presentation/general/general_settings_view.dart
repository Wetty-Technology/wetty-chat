import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/app/routing/route_names.dart';
import 'package:chahua/core/settings/app_settings_store.dart';
import 'package:chahua/features/settings/presentation/settings_components.dart';
import 'package:chahua/l10n/app_localizations.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class GeneralSettingsPage extends ConsumerWidget {
  const GeneralSettingsPage({super.key, this.onOpenLanguage, this.onOpenCache});

  final VoidCallback? onOpenLanguage;
  final VoidCallback? onOpenCache;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(appSettingsProvider);

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(middle: Text(l10n.settingsGeneral)),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            SettingsSectionCard(
              section: SettingsSectionData(
                items: [
                  SettingsItemData(
                    title: l10n.settingsLanguage,
                    icon: CupertinoIcons.globe,
                    iconColor: const Color(0xFF3A7DFF),
                    trailingText: settings.language.displayName(l10n),
                    trailingTextSize: AppFontSizes.body,
                    titleFontSize: AppFontSizes.body,
                    titleFontWeight: AppFontWeights.medium,
                    onTap:
                        onOpenLanguage ??
                        () => context.push(AppRoutes.language),
                  ),
                  SettingsItemData(
                    title: l10n.settingsCache,
                    icon: CupertinoIcons.tray_full,
                    iconColor: const Color(0xFF5E5CE6),
                    titleFontSize: AppFontSizes.body,
                    titleFontWeight: AppFontWeights.medium,
                    onTap: onOpenCache ?? () => context.push(AppRoutes.cache),
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
