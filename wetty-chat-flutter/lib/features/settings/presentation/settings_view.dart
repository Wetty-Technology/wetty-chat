import 'package:flutter/cupertino.dart';

import '../../../app/theme/style_config.dart';
import 'general_settings_view.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Settings'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Icon(CupertinoIcons.back, size: 28),
        ),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Padding(
              padding: EdgeInsets.only(left: 2, bottom: 8),
              child: Text('通用', style: appSectionTitleTextStyle(context)),
            ),
            Container(
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground.resolveFrom(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: CupertinoButton(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                onPressed: () => Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (_) => const GeneralSettingsPage(),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3A7DFF).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.gear_alt_fill,
                        size: 18,
                        color: Color(0xFF3A7DFF),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '通用',
                        style: appTextStyle(
                          context,
                          fontSize: AppFontSizes.bodySmall,
                        ),
                      ),
                    ),
                    Icon(
                      CupertinoIcons.chevron_right,
                      size: IconSizes.iconSize,
                      color: CupertinoColors.systemGrey3.resolveFrom(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
