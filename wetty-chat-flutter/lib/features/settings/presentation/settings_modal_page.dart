import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../../stickers/presentation/sticker_pack_detail_page.dart';
import '../../stickers/presentation/sticker_pack_list_page.dart';
import 'cache_settings_view.dart';
import 'dev_session_settings_view.dart';
import 'font_size_settings_view.dart';
import 'language_settings_view.dart';
import 'notification_settings_view.dart';
import 'profile_settings_view.dart';
import 'settings_content.dart';

class SettingsModalPage extends StatelessWidget {
  const SettingsModalPage({super.key});

  static const double _maxWidth = 520;
  static const double _maxHeight = 720;
  static const double _outerMargin = 32;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;
        final width = isCompact
            ? constraints.maxWidth
            : math.min(_maxWidth, constraints.maxWidth - (_outerMargin * 2));
        final height = isCompact
            ? constraints.maxHeight
            : math.min(_maxHeight, constraints.maxHeight - (_outerMargin * 2));

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.pop(),
          child: SafeArea(
            child: Center(
              child: GestureDetector(
                onTap: () {},
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(isCompact ? 0 : 16),
                  child: CupertinoPopupSurface(
                    isSurfacePainted: true,
                    child: SizedBox(
                      width: width,
                      height: height,
                      child: _SettingsModalNavigator(
                        onClose: () => context.pop(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SettingsModalNavigator extends StatelessWidget {
  const _SettingsModalNavigator({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      onGenerateRoute: (settings) {
        return CupertinoPageRoute<void>(
          settings: settings,
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            return SettingsContent(
              automaticallyImplyLeading: false,
              leading: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: onClose,
                child: Icon(CupertinoIcons.xmark, semanticLabel: l10n.close),
              ),
              onOpenStickerPacks: () => _openStickerPacks(context),
              onOpenLanguage: () =>
                  _push(context, const LanguageSettingsPage()),
              onOpenFontSize: () =>
                  _push(context, const FontSizeSettingsPage()),
              onOpenCache: () => _push(context, const CacheSettingsPage()),
              onOpenProfile: () => _push(context, const ProfileSettingsPage()),
              onOpenDevSession: () =>
                  _push(context, const DevSessionSettingsPage()),
              onOpenNotifications: () =>
                  _push(context, const NotificationSettingsPage()),
            );
          },
        );
      },
    );
  }

  void _push(BuildContext context, Widget page) {
    Navigator.of(context).push(CupertinoPageRoute<void>(builder: (_) => page));
  }

  void _openStickerPacks(BuildContext context) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (context) {
          return StickerPackListPage(
            onOpenPack: (packId) {
              _push(context, StickerPackDetailPage(packId: packId));
            },
          );
        },
      ),
    );
  }
}
