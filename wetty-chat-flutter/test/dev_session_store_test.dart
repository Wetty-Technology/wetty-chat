import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wetty_chat_flutter/core/session/dev_session_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DevSessionStore.instance.init();
  });

  test('defaults to uid 1 when no preference is stored', () {
    expect(
      DevSessionStore.instance.currentUserId,
      DevSessionStore.defaultUserId,
    );
  });

  test('persists and restores the selected uid', () async {
    await DevSessionStore.instance.setCurrentUserId(42);
    expect(DevSessionStore.instance.currentUserId, 42);

    await DevSessionStore.instance.init();
    expect(DevSessionStore.instance.currentUserId, 42);
  });

  test('resetToDefault restores uid 1', () async {
    await DevSessionStore.instance.setCurrentUserId(9);
    await DevSessionStore.instance.resetToDefault();

    expect(
      DevSessionStore.instance.currentUserId,
      DevSessionStore.defaultUserId,
    );
  });
}
