import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wetty_chat_flutter/core/providers/shared_preferences_provider.dart';
import 'package:wetty_chat_flutter/core/session/dev_session_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  });

  tearDown(() => container.dispose());

  test('defaults to uid 1 when no preference is stored', () {
    expect(
      container.read(devSessionProvider),
      DevSessionNotifier.defaultUserId,
    );
  });

  test('persists and restores the selected uid', () async {
    await container.read(devSessionProvider.notifier).setCurrentUserId(42);
    expect(container.read(devSessionProvider), 42);
  });

  test('resetToDefault restores uid 1', () async {
    await container.read(devSessionProvider.notifier).setCurrentUserId(9);
    await container.read(devSessionProvider.notifier).resetToDefault();

    expect(
      container.read(devSessionProvider),
      DevSessionNotifier.defaultUserId,
    );
  });
}
