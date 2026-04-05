import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wetty_chat_flutter/shared/presentation/app_divider.dart';

import '../../../app/theme/style_config.dart';
import '../../../core/settings/app_settings_store.dart';
import 'settings_components.dart';

class FontSizeSettingsPage extends ConsumerWidget {
  const FontSizeSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messageFontSize = ref.watch(appSettingsProvider).fontSize;
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: const CupertinoNavigationBar(middle: Text('Font Size')),
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
                    'Messages Font Size',
                    style: appSectionTitleTextStyle(context),
                  ),
                  const SizedBox(height: 10),
                  MessageFontSizeSlider(
                    value: messageFontSize,
                    onChanged: (value) {
                      ref
                          .read(appSettingsProvider.notifier)
                          .setChatMessageFontSize(value);
                    },
                  ),
                  const SizedBox(height: 12),
                  AppDivider(),
                  const SizedBox(height: 12),
                  // show the example display
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
        ),
      ),
    );
  }
}
