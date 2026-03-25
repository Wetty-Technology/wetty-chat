import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/config/auth_store.dart';

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

  test('extractToken accepts a raw JWT', () {
    final token = buildToken(42);

    expect(AuthStore.instance.extractToken(token), token);
  });

  test('extractToken accepts a login result URL', () {
    final token = buildToken(7);
    final loginResult = 'https://chahui.app/landing?token=$token';

    expect(AuthStore.instance.extractToken(loginResult), token);
  });

  test('extractToken accepts a JSON payload with token', () {
    final token = buildToken(9);
    final loginResult = jsonEncode({'token': token});

    expect(AuthStore.instance.extractToken(loginResult), token);
  });
}
