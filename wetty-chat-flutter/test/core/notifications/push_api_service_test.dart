import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chahua/core/notifications/push_api_service.dart';
import 'package:chahua/core/notifications/push_platform_client.dart';

void main() {
  group('PushApiService', () {
    test(
      'serializes subscription descriptor for subscribe/unsubscribe',
      () async {
        final requests = <RequestOptions>[];
        final dio = Dio();
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              requests.add(options);
              handler.resolve(Response<void>(requestOptions: options));
            },
          ),
        );
        final service = PushApiService(dio);
        const descriptor = PushSubscriptionDescriptor(
          provider: 'apns',
          deviceToken: 'token-1',
          environment: 'sandbox',
        );

        await service.subscribe(descriptor);
        await service.unsubscribe(descriptor);

        expect(requests.map((request) => request.path), [
          '/push/subscribe',
          '/push/unsubscribe',
        ]);
        expect(requests.first.data, {
          'provider': 'apns',
          'deviceToken': 'token-1',
          'environment': 'sandbox',
        });
        expect(requests.last.data, requests.first.data);
      },
    );

    test('serializes descriptor into subscription status query', () async {
      RequestOptions? capturedRequest;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedRequest = options;
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                data: <String, dynamic>{
                  'hasActiveSubscription': true,
                  'hasMatchingSubscription': true,
                },
              ),
            );
          },
        ),
      );
      final service = PushApiService(dio);

      final response = await service.getSubscriptionStatus(
        descriptor: const PushSubscriptionDescriptor(
          provider: 'apns',
          deviceToken: 'token-2',
          environment: 'production',
        ),
      );

      expect(response.hasActiveSubscription, isTrue);
      expect(response.hasMatchingSubscription, isTrue);
      expect(capturedRequest?.path, '/push/subscription-status');
      expect(capturedRequest?.queryParameters, {
        'provider': 'apns',
        'deviceToken': 'token-2',
        'environment': 'production',
      });
    });
  });
}
