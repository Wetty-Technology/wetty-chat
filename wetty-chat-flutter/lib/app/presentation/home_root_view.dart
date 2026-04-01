import 'package:flutter/cupertino.dart';

import '../../features/chats/chats.dart';
import '../../features/settings/settings.dart';

class HomeRootPage extends StatelessWidget {
  const HomeRootPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.chat_bubble_2),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.gear),
            label: 'Settings',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        switch (index) {
          case 0:
            return CupertinoTabView(builder: (_) => const ChatPage());
          case 1:
            return CupertinoTabView(builder: (_) => const SettingsPage());
        }
        return CupertinoTabView(builder: (_) => const ChatPage());
      },
    );
  }
}
