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
      onOpenLanguage: () => context.push(AppRoutes.language),
      onOpenFontSize: () => context.push(AppRoutes.fontSize),
      onOpenCache: () => context.push(AppRoutes.cache),
      onOpenProfile: () => context.push(AppRoutes.profile),
      onOpenDevSession: () => context.push(AppRoutes.devSession),
      onOpenNotifications: () => context.push(AppRoutes.notifications),
    );
  }
}
