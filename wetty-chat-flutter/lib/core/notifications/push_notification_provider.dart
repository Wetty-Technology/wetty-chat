import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/shared_preferences_provider.dart';
import '../session/dev_session_store.dart';
import 'apns_channel.dart';
import 'push_api_service.dart';

class PushNotificationState {
  const PushNotificationState({
    this.permissionStatus = 'notDetermined',
    this.deviceToken,
    this.apnsEnvironment,
    this.isSubscribed = false,
    this.isLoading = false,
    this.lastError,
  });

  final String permissionStatus;
  final String? deviceToken;
  final String? apnsEnvironment;
  final bool isSubscribed;
  final bool isLoading;
  final String? lastError;

  bool get isAuthorized => permissionStatus == 'authorized';
  bool get isDenied => permissionStatus == 'denied';

  /// Has token + permission but backend subscription failed or not attempted.
  bool get needsSubscription =>
      isAuthorized && deviceToken != null && !isSubscribed && !isLoading;

  PushNotificationState copyWith({
    String? permissionStatus,
    String? deviceToken,
    String? apnsEnvironment,
    bool? isSubscribed,
    bool? isLoading,
    String? lastError,
    bool clearDeviceToken = false,
    bool clearError = false,
  }) {
    return PushNotificationState(
      permissionStatus: permissionStatus ?? this.permissionStatus,
      deviceToken: clearDeviceToken ? null : (deviceToken ?? this.deviceToken),
      apnsEnvironment: apnsEnvironment ?? this.apnsEnvironment,
      isSubscribed: isSubscribed ?? this.isSubscribed,
      isLoading: isLoading ?? this.isLoading,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }
}

class PushNotificationNotifier extends Notifier<PushNotificationState> {
  static const String _deviceTokenKey = 'push_apns_device_token';

  late SharedPreferences _prefs;
  late ApnsChannel _apns;
  late PushApiService _api;
  StreamSubscription<String>? _tokenSub;
  StreamSubscription<String>? _tokenErrorSub;

  @override
  PushNotificationState build() {
    _prefs = ref.read(sharedPreferencesProvider);
    _apns = ref.read(apnsChannelProvider);
    _api = ref.read(pushApiServiceProvider);

    // Restore persisted device token.
    final savedToken = _prefs.getString(_deviceTokenKey);

    if (Platform.isIOS) {
      // Listen for token updates and errors from native side.
      _tokenSub = _apns.onDeviceToken.listen(_onTokenReceived);
      _tokenErrorSub = _apns.onDeviceTokenError.listen(_onTokenError);
      ref.onDispose(() {
        _tokenSub?.cancel();
        _tokenErrorSub?.cancel();
      });

      // Kick off async initialization after returning initial state.
      Future.microtask(_initialize);
    }

    return PushNotificationState(deviceToken: savedToken);
  }

  /// Runs after build() — refreshes permission and auto-subscribes if possible.
  Future<void> _initialize() async {
    if (!Platform.isIOS) return;
    await _refreshPermissionStatus();

    // If we have a saved token and permission is granted, try to subscribe.
    // This handles the case where a previous subscribe call failed.
    final session = ref.read(authSessionProvider);
    if (state.needsSubscription && session.isAuthenticated) {
      await _doSubscribe();
    }
  }

  Future<void> _refreshPermissionStatus() async {
    try {
      final status = await _apns.getPermissionStatus();
      state = state.copyWith(permissionStatus: status);
    } catch (e) {
      developer.log(
        'Failed to get permission status: $e',
        name: 'PushNotification',
      );
    }
  }

  /// Request notification permission and register for remote notifications.
  /// Call this from the notification settings page or on first login.
  Future<void> requestPermissionAndRegister() async {
    if (!Platform.isIOS) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _apns.requestPermission();
      final granted = result['granted'] as bool? ?? false;
      final status = result['status'] as String? ?? 'unknown';
      state = state.copyWith(permissionStatus: status, isLoading: false);

      if (granted) {
        await _apns.registerForRemoteNotifications();
        // Token will arrive asynchronously via onDeviceToken stream.
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, lastError: e.toString());
    }
  }

  /// Re-register the current device token with the backend.
  /// Safe to call repeatedly — skips if already subscribed or in progress.
  /// Called on login, app resume, and after failed attempts.
  Future<void> ensureSubscribed() async {
    if (!Platform.isIOS) return;
    if (state.isSubscribed || state.isLoading) return;

    final session = ref.read(authSessionProvider);
    if (!session.isAuthenticated) return;

    if (state.needsSubscription) {
      await _doSubscribe();
    }
  }

  /// Manual retry — always attempts even if isSubscribed is true
  /// (re-registers in case the backend lost the token).
  Future<void> retrySubscription() async {
    if (!Platform.isIOS) return;
    final token = state.deviceToken;
    if (token == null) {
      // No token at all — re-request from iOS.
      if (state.isAuthorized) {
        state = state.copyWith(isLoading: true, clearError: true);
        await _apns.registerForRemoteNotifications();
        // Token arrives via stream → _onTokenReceived handles the rest.
      } else {
        await requestPermissionAndRegister();
      }
      return;
    }
    await _doSubscribe();
  }

  /// Unsubscribe from push notifications on the backend and unregister.
  Future<void> unsubscribe() async {
    if (!Platform.isIOS) return;
    final token = state.deviceToken;
    final env = state.apnsEnvironment;
    if (token != null && env != null) {
      try {
        await _api.unsubscribe(deviceToken: token, environment: env);
        developer.log('Unsubscribed from push', name: 'PushNotification');
      } catch (e) {
        developer.log('Failed to unsubscribe: $e', name: 'PushNotification');
      }
    }
    state = state.copyWith(isSubscribed: false);
  }

  void _onTokenError(String error) {
    developer.log(
      'Token registration failed: $error',
      name: 'PushNotification',
    );
    state = state.copyWith(
      isLoading: false,
      lastError: 'APNs registration failed: $error',
    );
  }

  void _onTokenReceived(String token) {
    developer.log('Token received, subscribing...', name: 'PushNotification');
    state = state.copyWith(deviceToken: token, clearError: true);
    _prefs.setString(_deviceTokenKey, token);

    // Only auto-subscribe if the user is authenticated.
    final session = ref.read(authSessionProvider);
    if (session.isAuthenticated) {
      _doSubscribe();
    }
  }

  Future<void> _doSubscribe() async {
    final token = state.deviceToken;
    if (token == null) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final env = await _resolveEnvironment();
      await _api.subscribe(deviceToken: token, environment: env);
      state = state.copyWith(isSubscribed: true, isLoading: false);
      developer.log('Subscribed to push (env=$env)', name: 'PushNotification');
    } catch (e) {
      developer.log('Failed to subscribe: $e', name: 'PushNotification');
      state = state.copyWith(
        isSubscribed: false,
        isLoading: false,
        lastError: e.toString(),
      );
    }
  }

  /// Always re-detects from the native side — never cached to disk since it
  /// depends on the provisioning profile which can change between builds.
  Future<String> _resolveEnvironment() async {
    String env;
    try {
      env = await _apns.getApnsEnvironment();
    } catch (e) {
      developer.log(
        'Failed to detect APNs environment, defaulting to production: $e',
        name: 'PushNotification',
      );
      env = 'production';
    }
    state = state.copyWith(apnsEnvironment: env);
    return env;
  }
}

final pushNotificationProvider =
    NotifierProvider<PushNotificationNotifier, PushNotificationState>(
      PushNotificationNotifier.new,
    );
