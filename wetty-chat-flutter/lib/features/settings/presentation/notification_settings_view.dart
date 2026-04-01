import 'package:flutter/cupertino.dart';

class NotificationSettingsPage extends StatelessWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Notifications'),
      ),
      child: SafeArea(
        child: SizedBox.expand(),
      ),
    );
  }
}
