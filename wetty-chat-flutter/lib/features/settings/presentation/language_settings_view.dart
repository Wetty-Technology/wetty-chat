import 'package:flutter/cupertino.dart';

import '../../../core/settings/app_settings_store.dart';
import '../../../l10n/app_localizations.dart';

class LanguageSettingsPage extends StatelessWidget {
  const LanguageSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.settingsLanguage),
      ),
      child: SafeArea(
        child: AnimatedBuilder(
          animation: AppSettingsStore.instance,
          builder: (context, _) {
            final current = AppSettingsStore.instance.language;
            return CupertinoListSection.insetGrouped(
              children: [
                for (final language in AppLanguage.values)
                  CupertinoListTile(
                    title: Text(language.displayName(l10n)),
                    trailing: language == current
                        ? const Icon(
                            CupertinoIcons.checkmark,
                            color: CupertinoColors.activeBlue,
                            size: 20,
                          )
                        : null,
                    onTap: () {
                      AppSettingsStore.instance.setLanguage(language);
                      Navigator.of(context).pop();
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
