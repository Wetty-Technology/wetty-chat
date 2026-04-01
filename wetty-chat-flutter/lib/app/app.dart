import 'package:flutter/cupertino.dart';

import 'theme/style_config.dart';
import '../features/auth/auth.dart';
import 'presentation/home_root_view.dart';

class WettyChatApp extends StatelessWidget {
  const WettyChatApp({super.key, this.home});

  final Widget? home;

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      theme: appCupertinoTheme,

      /// For now, the home page directs to the chat list page
      // TODO: implement and verify the auth later
      home: home ?? const HomeRootPage(),
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
