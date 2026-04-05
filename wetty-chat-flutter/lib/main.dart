import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'core/network/api_config.dart';
import 'core/providers/shared_preferences_provider.dart';
import 'features/chats/chats.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  MediaPreviewCache.instance.initialize();

  final prefs = await SharedPreferences.getInstance();

  debugPrint('[APP] API_BASE_URL=$apiBaseUrl');

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const WettyChatApp(),
    ),
  );
}
