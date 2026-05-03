import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/route_names.dart';
import 'settings_content.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsContent(
      onOpenStickerPacks: () => context.push(AppRoutes.stickerPacks),
      onOpenGeneral: () => context.push(AppRoutes.general),
      onOpenAppearance: () => context.push(AppRoutes.appearance),
      onOpenDevSession: () => context.push(AppRoutes.devSession),
      onOpenNotifications: () => context.push(AppRoutes.notifications),
    );
  }
}
