import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wetty_chat_flutter/app/app.dart';
import 'package:wetty_chat_flutter/core/session/dev_session_store.dart';
import 'package:wetty_chat_flutter/core/settings/app_settings_store.dart';

void main() {
  testWidgets('WettyChatApp builds a CupertinoApp.router shell', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await DevSessionStore.instance.init();
    await AppSettingsStore.instance.init();

    await tester.pumpWidget(const WettyChatApp());
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoApp), findsOneWidget);
  });
}
