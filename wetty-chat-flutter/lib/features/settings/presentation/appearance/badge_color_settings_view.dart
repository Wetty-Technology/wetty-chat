import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/core/settings/app_settings_store.dart';
import 'package:chahua/l10n/app_localizations.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BadgeColorSettingsPage extends ConsumerWidget {
  const BadgeColorSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(appSettingsProvider);
    final defaults = AppColorTheme.resolve(
      brightness: context.appBrightness,
      overrides: const AppColorThemeOverrides(),
    );
    final selectedColor =
        settings.colorThemeOverrides.unreadBadge ?? defaults.unreadBadge;
    final isDefault = settings.colorThemeOverrides.unreadBadge == null;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(middle: Text(l10n.badgeColor)),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground.resolveFrom(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.badgeColorPreview,
                    style: appSectionTitleTextStyle(context),
                  ),
                  const SizedBox(height: 12),
                  _BadgePreview(color: selectedColor),
                  const SizedBox(height: 16),
                  Material(
                    type: MaterialType.transparency,
                    child: ColorPicker(
                      color: selectedColor,
                      onColorChanged: (color) {
                        ref
                            .read(appSettingsProvider.notifier)
                            .setUnreadBadgeColor(color);
                      },
                      enableOpacity: false,
                      showColorCode: true,
                      showColorName: false,
                      wheelDiameter: 220,
                      pickersEnabled: const <ColorPickerType, bool>{
                        ColorPickerType.both: false,
                        ColorPickerType.primary: false,
                        ColorPickerType.accent: false,
                        ColorPickerType.bw: false,
                        ColorPickerType.custom: false,
                        ColorPickerType.wheel: true,
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              color: CupertinoColors.systemBackground.resolveFrom(context),
              disabledColor: CupertinoColors.systemBackground.resolveFrom(
                context,
              ),
              onPressed: isDefault
                  ? null
                  : () {
                      ref
                          .read(appSettingsProvider.notifier)
                          .resetUnreadBadgeColor();
                    },
              child: Text(
                l10n.resetBadgeColor,
                style: appTextStyle(
                  context,
                  color: isDefault
                      ? context.appColors.textSecondary
                      : CupertinoColors.activeBlue.resolveFrom(context),
                  fontSize: AppFontSizes.body,
                  fontWeight: AppFontWeights.medium,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgePreview extends StatelessWidget {
  const _BadgePreview({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final textColor = AppColorTheme.badgeTextColorFor(color);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        constraints: const BoxConstraints(minWidth: 24),
        child: Text(
          '12',
          textAlign: TextAlign.center,
          style: appTextStyle(
            context,
            color: textColor,
            fontSize: AppFontSizes.unreadBadge,
            fontWeight: AppFontWeights.semibold,
          ),
        ),
      ),
    );
  }
}
