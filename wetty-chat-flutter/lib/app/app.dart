import 'package:flutter/cupertino.dart';
import '../l10n/app_localizations.dart';

import 'theme/style_config.dart';
import '../core/settings/app_settings_store.dart';
import '../features/auth/auth.dart';
import 'presentation/home_root_view.dart';

class WettyChatApp extends StatelessWidget {
  const WettyChatApp({super.key, this.home});

  final Widget? home;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettingsStore.instance,
      builder: (context, _) {
        final locale = AppSettingsStore.instance.language.toLocale();
        return CupertinoApp(
          theme: appCupertinoTheme,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          /// For now, the home page directs to the chat list page
          // TODO: implement and verify the auth later
          home: home ?? const HomeRootPage(),
        );
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AuthStore.instance,
      builder: (context, _) {
        if (AuthStore.instance.hasToken) {
          return const HomeRootPage();
        }
        return const TokenImportPage();
      },
    );
  }
}
