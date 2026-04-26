import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chahua/core/notifications/apns_channel.dart';
import 'package:chahua/core/notifications/push_platform_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UnsupportedPushPlatformClient', () {
    test('reports unsupported and no-ops platform calls', () async {
      const client = UnsupportedPushPlatformClient();

      expect(client.isSupported, isFalse);
      expect(await client.getPermissionStatus(), 'unsupported');
      expect(
        await client.requestPermission(),
        isA<PushPermissionRequestResult>(),
      );
      expect(await client.getLaunchNotification(), isNull);
      expect(await client.subscriptionDescriptorForToken('token'), isNull);
      expect(await client.onDeviceToken.toList(), isEmpty);

      await client.registerForRemoteNotifications();
      await client.unregisterForRemoteNotifications();
    });
  });

  group('ApnsPushPlatformClient', () {
    const channelName = 'app.chahua.chat/push_notifications';
    final calls = <MethodCall>[];
    var launchPayload = <String, dynamic>{'chatId': '10'};
    var apnsEnvironment = 'sandbox';

    setUp(() {
      calls.clear();
      launchPayload = <String, dynamic>{'chatId': '10'};
      apnsEnvironment = 'sandbox';
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel(channelName), (
            call,
          ) async {
            calls.add(call);
            return switch (call.method) {
              'requestPermission' => <String, dynamic>{
                'granted': true,
                'status': 'authorized',
              },
              'getPermissionStatus' => 'authorized',
              'registerForRemoteNotifications' => null,
              'unregisterForRemoteNotifications' => null,
              'getApnsEnvironment' => apnsEnvironment,
              'getLaunchNotification' => launchPayload,
              _ => null,
            };
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel(channelName), null);
    });

    test(
      'delegates permission and registration calls to APNs channel',
      () async {
        final client = ApnsPushPlatformClient(ApnsChannel());

        final permission = await client.requestPermission();
        final status = await client.getPermissionStatus();
        await client.registerForRemoteNotifications();
        await client.unregisterForRemoteNotifications();

        expect(permission.granted, isTrue);
        expect(permission.status, 'authorized');
        expect(status, 'authorized');
        expect(
          calls.map((call) => call.method),
          containsAllInOrder([
            'requestPermission',
            'getPermissionStatus',
            'registerForRemoteNotifications',
            'unregisterForRemoteNotifications',
          ]),
        );
      },
    );

    test(
      'builds APNs subscription descriptor from native environment',
      () async {
        final client = ApnsPushPlatformClient(ApnsChannel());

        final descriptor = await client.subscriptionDescriptorForToken(
          'abc123',
        );

        expect(descriptor.provider, 'apns');
        expect(descriptor.deviceToken, 'abc123');
        expect(descriptor.environment, 'sandbox');
        expect(calls.single.method, 'getApnsEnvironment');
      },
    );

    test('falls back to production when environment lookup fails', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel(channelName), (
            call,
          ) async {
            throw PlatformException(code: 'missing');
          });
      final client = ApnsPushPlatformClient(ApnsChannel());

      final descriptor = await client.subscriptionDescriptorForToken('abc123');

      expect(descriptor.environment, 'production');
    });

    test('reads cold-start launch notification from APNs channel', () async {
      launchPayload = <String, dynamic>{'chatId': '42', 'messageId': '9'};
      final client = ApnsPushPlatformClient(ApnsChannel());

      final payload = await client.getLaunchNotification();

      expect(payload, launchPayload);
      expect(calls.single.method, 'getLaunchNotification');
    });
  });
}
