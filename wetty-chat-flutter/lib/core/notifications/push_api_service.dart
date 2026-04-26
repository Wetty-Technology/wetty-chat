import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/dio_client.dart';
import 'push_platform_client.dart';

/// Raw HTTP calls for push subscription endpoints. No state.
class PushApiService {
  final Dio _dio;

  PushApiService(this._dio);

  /// Register a platform push token with the backend.
  Future<void> subscribe(PushSubscriptionDescriptor descriptor) async {
    await _dio.post<void>('/push/subscribe', data: descriptor.toJson());
  }

  /// Remove a platform push token from the backend.
  Future<void> unsubscribe(PushSubscriptionDescriptor descriptor) async {
    await _dio.post<void>('/push/unsubscribe', data: descriptor.toJson());
  }

  /// Check whether a specific device token is registered.
  Future<SubscriptionStatusResponse> getSubscriptionStatus({
    required PushSubscriptionDescriptor descriptor,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/push/subscription-status',
      queryParameters: descriptor.toQueryParameters(),
    );
    return SubscriptionStatusResponse.fromJson(response.data!);
  }
}

class SubscriptionStatusResponse {
  final bool hasActiveSubscription;
  final bool? hasMatchingSubscription;

  const SubscriptionStatusResponse({
    required this.hasActiveSubscription,
    this.hasMatchingSubscription,
  });

  factory SubscriptionStatusResponse.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatusResponse(
      hasActiveSubscription: json['hasActiveSubscription'] as bool,
      hasMatchingSubscription: json['hasMatchingSubscription'] as bool?,
    );
  }
}

final pushApiServiceProvider = Provider<PushApiService>((ref) {
  return PushApiService(ref.watch(dioProvider));
});
