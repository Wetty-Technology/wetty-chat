import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:media_kit/media_kit.dart';

import 'config/auth_store.dart';
import 'data/services/media_preview_cache.dart';
import 'data/services/websocket_service.dart';
import 'ui/auth/token_import_page.dart';
import 'ui/chat_list/chat_list_view.dart';
import 'ui/shared/draft_store.dart';
import 'ui/shared/settings_store.dart';

const _miSansBaseTextStyle = TextStyle(
  fontFamily: 'MiSans',
  fontWeight: FontWeight.w400,
);

const _miSansCupertinoTheme = CupertinoThemeData(
  brightness: Brightness.light,
  textTheme: CupertinoTextThemeData(
    textStyle: _miSansBaseTextStyle,
    actionTextStyle: _miSansBaseTextStyle,
    tabLabelTextStyle: _miSansBaseTextStyle,
    navTitleTextStyle: _miSansBaseTextStyle,
    navLargeTitleTextStyle: _miSansBaseTextStyle,
    navActionTextStyle: _miSansBaseTextStyle,
    pickerTextStyle: _miSansBaseTextStyle,
    dateTimePickerTextStyle: _miSansBaseTextStyle,
  ),
);

TextStyle _appTextStyle(BuildContext context) {
  return _miSansBaseTextStyle.copyWith(
    color: CupertinoColors.label.resolveFrom(context),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  unawaited(Future<void>(MediaPreviewCache.instance.initialize));
  await AuthStore.instance.init();
  await DraftStore.instance.init();
  await SettingsStore.instance.init();
  WebSocketService.instance.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.home});

  final Widget? home;

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      theme: _miSansCupertinoTheme,
      builder: (context, child) {
        return DefaultTextStyle.merge(
          style: _appTextStyle(context),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: home ?? const AuthGate(),
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
          return const ChatPage();
        }
        return const TokenImportPage();
      },
    );
  }
}
