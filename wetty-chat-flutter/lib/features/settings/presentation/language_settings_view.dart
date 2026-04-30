import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/app_settings_store.dart';
import '../../../l10n/app_localizations.dart';

class LanguageSettingsPage extends ConsumerWidget {
  const LanguageSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final current = ref.watch(appSettingsProvider).language;
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.settingsLanguage),
      ),
      child: SafeArea(
        child: CupertinoListSection.insetGrouped(
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
                  ref.read(appSettingsProvider.notifier).setLanguage(language);
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}
