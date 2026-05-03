import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static const String unreadSummaryPayloadType = 'unreadSummary';
  static const String _channelId = 'wetty_background_unread';
  static const String _channelName = 'Unread messages';
  static const String _channelDescription =
      'Delayed background checks for unread messages.';
  static const int _unreadSummaryNotificationId = 1001;

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static final StreamController<String?> _tapController =
      StreamController<String?>.broadcast();

  static bool _initialized = false;

  static Stream<String?> get onPayloadTapped => _tapController.stream;

  static Future<void> initialize({bool handleTaps = true}) async {
    if (!Platform.isAndroid || _initialized) return;
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/launcher_icon'),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: handleTaps
          ? (response) => _tapController.add(response.payload)
          : null,
    );
    _initialized = true;
  }

  static Future<String?> getLaunchPayload() async {
    if (!Platform.isAndroid) return null;
    await initialize();
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    return details?.notificationResponse?.payload;
  }

  static Future<bool> areNotificationsEnabled() async {
    if (!Platform.isAndroid) return false;
    await initialize();
    return await _androidPlugin?.areNotificationsEnabled() ?? false;
  }

  static Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return false;
    await initialize();
    return await _androidPlugin?.requestNotificationsPermission() ?? false;
  }

  static Future<void> showUnreadSummary({
    required int totalUnreadCount,
    required int newUnreadCount,
  }) async {
    if (!Platform.isAndroid || totalUnreadCount <= 0 || newUnreadCount <= 0) {
      return;
    }
    await initialize(handleTaps: false);
    final enabled = await areNotificationsEnabled();
    if (!enabled) return;

    final payload = jsonEncode(<String, Object?>{
      'type': unreadSummaryPayloadType,
    });
    try {
      await _plugin.show(
        id: _unreadSummaryNotificationId,
        title: '茶话',
        body: '有 $newUnreadCount 条新的未读消息，共 $totalUnreadCount 条未读',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            category: AndroidNotificationCategory.message,
          ),
        ),
        payload: payload,
      );
    } catch (error, stackTrace) {
      developer.log(
        'Failed to show local unread notification',
        name: 'LocalNotification',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static bool isUnreadSummaryPayload(String? payload) {
    if (payload == null || payload.isEmpty) return false;
    try {
      final decoded = jsonDecode(payload);
      return decoded is Map<String, dynamic> &&
          decoded['type'] == unreadSummaryPayloadType;
    } on FormatException {
      return false;
    }
  }

  static AndroidFlutterLocalNotificationsPlugin? get _androidPlugin => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
}
