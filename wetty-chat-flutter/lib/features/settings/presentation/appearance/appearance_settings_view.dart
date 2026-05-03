import 'package:chahua/app/routing/route_names.dart';
import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/core/settings/app_settings_store.dart';
import 'package:chahua/features/settings/presentation/settings_components.dart';
import 'package:chahua/l10n/app_localizations.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AppearanceSettingsPage extends ConsumerWidget {
  const AppearanceSettingsPage({super.key, this.onOpenFontSize});

  final VoidCallback? onOpenFontSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(appSettingsProvider);

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.settingsAppearance),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            SettingsSectionCard(
              section: SettingsSectionData(
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
                        ref
                            .read(appSettingsProvider.notifier)
                            .setShowAllTab(value);
                      },
                    ),
                    onTap: () {
                      ref
                          .read(appSettingsProvider.notifier)
                          .setShowAllTab(!settings.showAllTab);
                    },
                  ),
                  SettingsItemData(
                    title: l10n.settingsTextSize,
                    icon: CupertinoIcons.textformat_size,
                    iconColor: const Color(0xFF34A853),
                    titleFontSize: AppFontSizes.body,
                    titleFontWeight: AppFontWeights.medium,
                    onTap:
                        onOpenFontSize ??
                        () => context.push(AppRoutes.fontSize),
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
