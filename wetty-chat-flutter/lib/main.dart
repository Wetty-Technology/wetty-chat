import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/network/api_config.dart';
import 'core/network/app_version.dart';
import 'core/notifications/background_polling_notifications.dart';
import 'core/notifications/local_notification_service.dart';
import 'core/providers/shared_preferences_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  await AppVersionHeader.initialize();
  await LocalNotificationService.initialize();
  await AndroidBackgroundPollingNotifications.initializeWorkmanager();

  debugPrint('[APP] API_BASE_URL=$apiBaseUrl');

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const WettyChatApp(),
    ),
  );
}
