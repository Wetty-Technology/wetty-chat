import 'package:flutter/cupertino.dart';

import '../../../app/theme/style_config.dart';
import '../../../core/settings/app_settings_store.dart';
import 'settings_components.dart';

class GeneralSettingsPage extends StatelessWidget {
  const GeneralSettingsPage({super.key});

  Future<void> _showLanguagePicker(BuildContext context) async {
    final currentLanguage = AppSettingsStore.instance.language;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('Language'),
        actions: [
          for (final language in AppLanguage.values)
            CupertinoActionSheetAction(
              isDefaultAction: language == currentLanguage,
              onPressed: () {
                AppSettingsStore.instance.setLanguage(language);
                Navigator.of(context).pop();
              },
              child: Text(_languageLabel(language)),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  String _languageLabel(AppLanguage language) {
    switch (language) {
      case AppLanguage.system:
        return 'System';
      case AppLanguage.english:
        return 'English';
      case AppLanguage.chinese:
        return 'Chinese';
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: const CupertinoNavigationBar(middle: Text('General')),
      child: SafeArea(
        child: AnimatedBuilder(
          animation: AppSettingsStore.instance,
          builder: (context, _) {
            final messageFontSize =
                AppSettingsStore.instance.chatMessageFontSize;
            final language = AppSettingsStore.instance.language;
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemBackground.resolveFrom(
                      context,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    onPressed: () => _showLanguagePicker(context),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Language',
                            style: appTextStyle(
                              context,
                              fontSize: AppFontSizes.bodySmall,
                            ),
                          ),
                        ),
                        Text(
                          _languageLabel(language),
                          style: appSecondaryTextStyle(
                            context,
                            fontSize: AppFontSizes.meta,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          CupertinoIcons.chevron_right,
                          size: IconSizes.iconSize,
                          color: CupertinoColors.systemGrey3.resolveFrom(
                            context,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
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
                      Text(
                        'Messages Font Size',
                        style: appSectionTitleTextStyle(context),
                      ),
                      const SizedBox(height: 10),
                      MessageFontSizeSlider(
                        value: messageFontSize,
                        onChanged: (value) {
                          AppSettingsStore.instance.setChatMessageFontSize(
                            value,
                          );
                        },
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
                              'SC',
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
                                    'Sample User',
                                    style: appSecondaryTextStyle(
                                      context,
                                      fontSize: AppFontSizes.meta,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'This is how your messages will look in chat.',
                                    style: appTextStyle(
                                      context,
                                      fontSize: messageFontSize,
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
