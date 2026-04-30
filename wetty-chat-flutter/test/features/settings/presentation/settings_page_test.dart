import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chahua/core/providers/shared_preferences_provider.dart';
import 'package:chahua/features/settings/presentation/cache_settings_view.dart';
import 'package:chahua/features/settings/presentation/settings_page.dart';
import 'package:chahua/l10n/app_localizations.dart';
import '../../../test_utils/path_provider_mock.dart';

void main() {
  setUpAll(setUpPathProviderMock);
  tearDownAll(tearDownPathProviderMock);

  testWidgets('settings page shows cache entry and opens cache page', (
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
              path: 'cache',
              builder: (context, state) => const CacheSettingsPage(),
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

    expect(find.text('Cache'), findsOneWidget);

    await tester.tap(find.text('Cache'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Storage Used'), findsOneWidget);
  });
}
