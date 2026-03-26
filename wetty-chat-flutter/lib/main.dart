import 'package:flutter/cupertino.dart';

import 'ui/shared/draft_store.dart';
import 'ui/shared/settings_store.dart';
import 'ui/chat_list/chat_list_view.dart';
import 'data/services/websocket_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DraftStore.instance.init();
  await SettingsStore.instance.init();
  WebSocketService.instance.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      theme: CupertinoThemeData(
        brightness: Brightness.light,
      ),
      home: ChatPage(),
    );
  }
}
