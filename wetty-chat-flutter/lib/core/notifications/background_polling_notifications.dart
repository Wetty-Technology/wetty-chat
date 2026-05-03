import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show Platform;
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'package:chahua/core/network/api_config.dart';
import 'package:chahua/core/providers/shared_preferences_provider.dart';
import 'package:chahua/core/session/dev_session_store.dart';

import 'local_notification_service.dart';

const String _taskUniqueName = 'wetty_android_unread_poll';
const String _taskName = 'wetty.android.unreadPoll';
const String _enabledKey = 'android_background_notification_polling_enabled';
const String _lastUnreadTotalKey = 'android_background_last_unread_total';

class BackgroundPollingNotificationState {
  const BackgroundPollingNotificationState({
    this.isSupported = false,
    this.isEnabled = false,
    this.notificationsEnabled = false,
    this.isLoading = false,
    this.lastError,
  });

  final bool isSupported;
  final bool isEnabled;
  final bool notificationsEnabled;
  final bool isLoading;
  final String? lastError;

  BackgroundPollingNotificationState copyWith({
    bool? isSupported,
    bool? isEnabled,
    bool? notificationsEnabled,
    bool? isLoading,
    String? lastError,
    bool clearError = false,
  }) {
    return BackgroundPollingNotificationState(
      isSupported: isSupported ?? this.isSupported,
      isEnabled: isEnabled ?? this.isEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      isLoading: isLoading ?? this.isLoading,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }
}

class BackgroundPollingNotificationNotifier
    extends Notifier<BackgroundPollingNotificationState> {
  late SharedPreferences _prefs;

  @override
  BackgroundPollingNotificationState build() {
    _prefs = ref.read(sharedPreferencesProvider);
    final supported = Platform.isAndroid;
    final enabled = supported && (_prefs.getBool(_enabledKey) ?? false);
    Future.microtask(refreshPermissionStatus);
    return BackgroundPollingNotificationState(
      isSupported: supported,
      isEnabled: enabled,
    );
  }

  Future<void> refreshPermissionStatus() async {
    if (!state.isSupported) return;
    final enabled = await LocalNotificationService.areNotificationsEnabled();
    state = state.copyWith(notificationsEnabled: enabled);
  }

  Future<void> setEnabled(bool enabled) async {
    if (!state.isSupported || state.isLoading) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      var notificationsEnabled = state.notificationsEnabled;
      if (enabled && !notificationsEnabled) {
        notificationsEnabled =
            await LocalNotificationService.requestPermission();
      }
      await _prefs.setBool(_enabledKey, enabled);
      if (enabled) {
        await AndroidBackgroundPollingNotifications.schedule();
      } else {
        await AndroidBackgroundPollingNotifications.cancel();
      }
      state = state.copyWith(
        isEnabled: enabled,
        notificationsEnabled: notificationsEnabled,
        isLoading: false,
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, lastError: error.toString());
    }
  }

  Future<void> ensureScheduledForAuthenticatedSession() async {
    if (!state.isSupported || !state.isEnabled) return;
    await AndroidBackgroundPollingNotifications.schedule();
  }

  Future<void> cancelScheduledTask() async {
    if (!state.isSupported) return;
    await AndroidBackgroundPollingNotifications.cancel();
  }
}

class AndroidBackgroundPollingNotifications {
  const AndroidBackgroundPollingNotifications._();

  static Future<void> initializeWorkmanager() async {
    if (!Platform.isAndroid) return;
    await Workmanager().initialize(_callbackDispatcher);
  }

  static Future<void> schedule() async {
    if (!Platform.isAndroid) return;
    await Workmanager().registerPeriodicTask(
      _taskUniqueName,
      _taskName,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
  }

  static Future<void> cancel() async {
    if (!Platform.isAndroid) return;
    await Workmanager().cancelByUniqueName(_taskUniqueName);
  }
}

@pragma('vm:entry-point')
void _callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != _taskName) return true;
    try {
      WidgetsFlutterBinding.ensureInitialized();
      DartPluginRegistrant.ensureInitialized();
      await _executeUnreadPoll();
      return true;
    } catch (error, stackTrace) {
      developer.log(
        'Background unread poll failed',
        name: 'BackgroundPollingNotifications',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    }
  });
}

Future<void> _executeUnreadPoll() async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_enabledKey) != true) return;

  final headers = _authHeadersFromPrefs(prefs);
  if (headers.isEmpty) return;

  final dio = Dio(
    BaseOptions(
      baseUrl: apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: <String, String>{
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        ...headers,
      },
    ),
  );

  try {
    final results = await Future.wait([
      dio.get<Map<String, dynamic>>('/chats/unread'),
      dio.get<Map<String, dynamic>>('/threads/unread'),
    ]);
    final chatUnread = _intValue(results[0].data?['unreadCount']);
    final threadUnread = _intValue(results[1].data?['unreadThreadCount']);
    final totalUnread = chatUnread + threadUnread;
    final previousUnread = prefs.getInt(_lastUnreadTotalKey);

    if (previousUnread != null && totalUnread > previousUnread) {
      await LocalNotificationService.showUnreadSummary(
        totalUnreadCount: totalUnread,
        newUnreadCount: totalUnread - previousUnread,
      );
    }
    await prefs.setInt(_lastUnreadTotalKey, totalUnread);
  } finally {
    dio.close();
  }
}

Map<String, String> _authHeadersFromPrefs(SharedPreferences prefs) {
  final jwt = prefs.getString(AuthSessionNotifier.jwtTokenStorageKey)?.trim();
  if (jwt != null && jwt.isNotEmpty) {
    return <String, String>{'Authorization': 'Bearer $jwt'};
  }
  final userId =
      prefs.getInt(AuthSessionNotifier.userIdStorageKey) ??
      AuthSessionNotifier.defaultUserId;
  return legacyApiAuthHeadersForUser(userId);
}

int _intValue(Object? value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

final backgroundPollingNotificationProvider =
    NotifierProvider<
      BackgroundPollingNotificationNotifier,
      BackgroundPollingNotificationState
    >(BackgroundPollingNotificationNotifier.new);
