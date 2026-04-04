import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';

import 'app/app.dart';
import 'core/network/api_config.dart';
import 'core/network/websocket_service.dart';
import 'core/session/dev_session_store.dart';
import 'core/settings/app_settings_store.dart';
import 'features/chats/chats.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  unawaited(Future<void>(MediaPreviewCache.instance.initialize));
  await DevSessionStore.instance.init();
  await ChatDraftStore.instance.init();
  await AppSettingsStore.instance.init();
  debugPrint('[APP] API_BASE_URL=$apiBaseUrl');
  await WebSocketService.instance.init();
  runApp(const WettyChatApp());
}
