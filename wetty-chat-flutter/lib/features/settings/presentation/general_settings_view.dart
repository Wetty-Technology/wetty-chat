import 'package:flutter/cupertino.dart';

import '../../../app/theme/style_config.dart';
import '../../../core/settings/app_settings_store.dart';

class GeneralSettingsPage extends StatelessWidget {
  const GeneralSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: const CupertinoNavigationBar(middle: Text('通用')),
      child: SafeArea(
        child: AnimatedBuilder(
          animation: AppSettingsStore.instance,
          builder: (context, _) {
            final scale = AppSettingsStore.instance.chatFontScale;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBackground.resolveFrom(
                      context,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('消息字体大小', style: appSectionTitleTextStyle(context)),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoSlider(
                          min: AppSettingsStore.minChatFontScale,
                          max: AppSettingsStore.maxChatFontScale,
                          value: scale,
                          onChanged: (value) {
                            AppSettingsStore.instance.setChatFontScale(value);
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '小',
                              style: appSecondaryTextStyle(
                                context,
                                fontSize: AppFontSizes.meta,
                              ),
                            ),
                            Text(
                              '大',
                              style: appSecondaryTextStyle(
                                context,
                                fontSize: AppFontSizes.meta,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 0.5,
                        color: CupertinoColors.separator.resolveFrom(context),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: Color(0xFF4CB1BC),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              '风纪',
                              style: appOnDarkTextStyle(
                                context,
                                fontSize: AppFontSizes.meta,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F0F0),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '风纪委员',
                                    style: appSecondaryTextStyle(
                                      context,
                                      fontSize: AppFontSizes.meta,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '这是你的消息在聊天中的显示效果。',
                                    style: appTextStyle(
                                      context,
                                      fontSize: AppFontSizes.body * scale,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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
