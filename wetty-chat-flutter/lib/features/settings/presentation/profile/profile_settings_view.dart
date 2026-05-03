import 'package:flutter/cupertino.dart';

class ProfileSettingsPage extends StatelessWidget {
  const ProfileSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text('Profile')),
      child: SafeArea(child: SizedBox.expand()),
    );
  }
}
