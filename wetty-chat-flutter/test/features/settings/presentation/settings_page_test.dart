import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chahua/core/providers/shared_preferences_provider.dart';
import 'package:chahua/features/settings/presentation/general/cache_settings_view.dart';
import 'package:chahua/features/settings/presentation/general/general_settings_view.dart';
import 'package:chahua/features/settings/presentation/settings_modal_page.dart';
import 'package:chahua/features/settings/presentation/settings_page.dart';
import 'package:chahua/l10n/app_localizations.dart';
import '../../../test_utils/path_provider_mock.dart';

void main() {
  setUpAll(setUpPathProviderMock);
  tearDownAll(tearDownPathProviderMock);

  testWidgets('settings page opens general submenu and cache page', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: '/settings',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
          routes: [
            GoRoute(
              path: 'general',
              builder: (context, state) => const GeneralSettingsPage(),
              routes: [
                GoRoute(
                  path: 'cache',
                  builder: (context, state) => const CacheSettingsPage(),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: CupertinoApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('General'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);

    await tester.tap(find.text('General'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Cache'), findsOneWidget);

    await tester.tap(find.text('Cache'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Storage Used'), findsOneWidget);
  });

  testWidgets('settings modal opens subpages in its local navigator', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CupertinoApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsModalPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('General'), findsOneWidget);

    await tester.tap(find.text('General'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Cache'), findsOneWidget);

    await tester.tap(find.text('Cache'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Storage Used'), findsOneWidget);
  });
}
