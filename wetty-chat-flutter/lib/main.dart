import 'package:flutter/cupertino.dart';
import 'config/auth_store.dart';
import 'config/realtime_service.dart';
import 'ui/auth/token_import_page.dart';
import 'ui/shared/draft_store.dart';
import 'ui/chat_list/chat_list_view.dart';

const _miSansBaseTextStyle = TextStyle(
  fontFamily: 'MiSans',
  fontWeight: FontWeight.w400,
);
TextStyle _appTextStyle(BuildContext context) {
  return _miSansBaseTextStyle.copyWith(
    color: CupertinoColors.label.resolveFrom(context),
  );
}

CupertinoTextThemeData _appTextTheme(BuildContext context) {
  final labelColor = CupertinoColors.label.resolveFrom(context);
  final secondaryColor = CupertinoColors.secondaryLabel.resolveFrom(context);
  final actionColor = CupertinoColors.activeBlue.resolveFrom(context);
  return CupertinoTextThemeData(
    textStyle: _miSansBaseTextStyle.copyWith(color: labelColor),
    actionTextStyle: _miSansBaseTextStyle.copyWith(color: actionColor),
    tabLabelTextStyle: _miSansBaseTextStyle.copyWith(color: secondaryColor),
    navTitleTextStyle: _miSansBaseTextStyle.copyWith(
      color: labelColor,
      fontSize: 17,
      fontWeight: FontWeight.w600,
    ),
    navLargeTitleTextStyle: _miSansBaseTextStyle.copyWith(
      color: labelColor,
      fontSize: 34,
      fontWeight: FontWeight.w600,
    ),
    navActionTextStyle: _miSansBaseTextStyle.copyWith(
      color: actionColor,
      fontSize: 17,
    ),
    pickerTextStyle: _miSansBaseTextStyle.copyWith(color: labelColor),
    dateTimePickerTextStyle: _miSansBaseTextStyle.copyWith(color: labelColor),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthStore.instance.init();
  await DraftStore.instance.init();
  RealtimeService.instance.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.home});
  final Widget? home;
  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      builder: (context, child) {
        final theme = CupertinoTheme.of(context).copyWith(
          brightness: MediaQuery.platformBrightnessOf(context),
          textTheme: _appTextTheme(context),
        );
        return CupertinoTheme(
          data: theme,
          child: DefaultTextStyle.merge(
            style: _appTextStyle(context),
            child: child ?? const SizedBox.shrink(),
          ),
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
