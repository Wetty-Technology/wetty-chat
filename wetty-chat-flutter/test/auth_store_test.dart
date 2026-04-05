import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wetty_chat_flutter/core/providers/shared_preferences_provider.dart';
import 'package:wetty_chat_flutter/features/auth/application/auth_store.dart';

void main() {
  String buildToken(int uid) {
    final header = base64Url
        .encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'})))
        .replaceAll('=', '');
    final payload = base64Url
        .encode(
          utf8.encode(jsonEncode({'uid': uid, 'cid': 'desktop', 'gen': 0})),
        )
        .replaceAll('=', '');
    return '$header.$payload.signature';
  }

  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  });

  tearDown(() => container.dispose());

  test('extractToken accepts a raw JWT', () {
    final token = buildToken(42);
    expect(container.read(authProvider.notifier).extractToken(token), token);
  });

  test('extractToken accepts a login result URL', () {
    final token = buildToken(7);
    final loginResult = 'https://chahui.app/landing?token=$token';
    expect(
      container.read(authProvider.notifier).extractToken(loginResult),
      token,
    );
  });

  test('extractToken accepts a JSON payload with token', () {
    final token = buildToken(9);
    final loginResult = jsonEncode({'token': token});
    expect(
      container.read(authProvider.notifier).extractToken(loginResult),
      token,
    );
  });
}
