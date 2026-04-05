import 'package:flutter/cupertino.dart';
import '../l10n/app_localizations.dart';

import 'routing/app_router.dart';
import 'theme/style_config.dart';
import '../core/settings/app_settings_store.dart';

class WettyChatApp extends StatelessWidget {
  const WettyChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettingsStore.instance,
      builder: (context, _) {
        final locale = AppSettingsStore.instance.language.toLocale();
        return CupertinoApp.router(
          theme: appCupertinoTheme,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: appRouter,
        );
      },
    );
  }
}
