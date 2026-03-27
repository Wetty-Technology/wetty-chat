import 'package:flutter/cupertino.dart';

import '../shared/settings_store.dart';
import 'general_settings_view.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
        context,
      ),
      navigationBar: const CupertinoNavigationBar(
        middle: Text('设置'),
      ),
      child: SafeArea(
        child: AnimatedBuilder(
          animation: SettingsStore.instance,
          builder: (context, _) {
            final isDarkModeEnabled = SettingsStore.instance.isDarkModeEnabled;
            final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
            final secondaryTextColor = CupertinoColors.secondaryLabel
                .resolveFrom(context);
            final cardColor = isDark
                ? const Color(0xFF1F2937)
                : CupertinoColors.systemBackground.resolveFrom(context);
            final cardBorderColor = isDark
                ? const Color(0xFF334155)
                : CupertinoColors.separator.resolveFrom(context);
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 2, bottom: 8),
                  child: Text(
                    '通用',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cardBorderColor),
                  ),
                  child: Column(
                    children: [
                      CupertinoButton(
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
                                color: const Color(0xFF3A7DFF)
                                    .withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                CupertinoIcons.gear_alt_fill,
                                size: 18,
                                color: Color(0xFF3A7DFF),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                '通用',
                                style: TextStyle(fontSize: 15),
                              ),
                            ),
                            Icon(
                              CupertinoIcons.chevron_right,
                              size: 16,
                              color: CupertinoColors.systemGrey3
                                  .resolveFrom(context),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 0.5,
                        color: cardBorderColor,
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '深色模式',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '开启后全局使用深色背景与浅色文字',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: secondaryTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            CupertinoSwitch(
                              value: isDarkModeEnabled,
                              onChanged: SettingsStore.instance.setDarkModeEnabled,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
