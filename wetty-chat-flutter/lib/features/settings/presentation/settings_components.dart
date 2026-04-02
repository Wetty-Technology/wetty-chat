import 'package:flutter/cupertino.dart';

import '../../../app/theme/style_config.dart';

class SettingsSectionData {
  const SettingsSectionData({
    required this.title,
    required this.items,
  });

  final String title;
  final List<SettingsItemData> items;
}

class SettingsItemData {
  const SettingsItemData({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.trailingText,
    this.trailingTextSize,
    this.titleColor,
    this.titleFontSize,
    this.titleFontWeight,
    this.isDestructive = false,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  final String? trailingText;
  final double? trailingTextSize;
  final Color? titleColor;
  final double? titleFontSize;
  final FontWeight? titleFontWeight;
  final bool isDestructive;
}

class SettingsSectionCard extends StatelessWidget {
  const SettingsSectionCard({
    super.key,
    required this.section,
  });

  final SettingsSectionData section;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Text(section.title, style: appSectionTitleTextStyle(context)),
        ),
        Container(
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground.resolveFrom(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              for (var index = 0; index < section.items.length; index++) ...[
                if (index > 0)
                  Container(
                    margin: const EdgeInsets.only(left: 54),
                    height: 0.5,
                    color: CupertinoColors.separator.resolveFrom(context),
                  ),
                SettingsActionRow(item: section.items[index]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class SettingsActionRow extends StatelessWidget {
  const SettingsActionRow({
    super.key,
    required this.item,
  });

  final SettingsItemData item;

  @override
  Widget build(BuildContext context) {
    final defaultLabelColor = item.isDestructive
        ? CupertinoColors.destructiveRed.resolveFrom(context)
        : CupertinoColors.label.resolveFrom(context);

    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onPressed: item.onTap,
      child: Row(
        children: [
          // the entry icon
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: item.iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, size: 18, color: item.iconColor),
          ),
          const SizedBox(width: 10),
          // the entry title
          Expanded(
            child: Text(
              item.title,
              style: appTextStyle(
                context,
                fontSize: item.titleFontSize ?? AppFontSizes.bodySmall,
                color: item.titleColor ?? defaultLabelColor,
                fontWeight: item.titleFontWeight,
              ),
            ),
          ),
          // the trailing text
          if (item.trailingText != null) ...[
            Text(
              item.trailingText!,
              style: appSecondaryTextStyle(
                context,
                fontSize: item.trailingTextSize ?? AppFontSizes.meta,
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (!item.isDestructive)
            Icon(
              CupertinoIcons.chevron_right,
              size: IconSizes.iconSize,
              color: CupertinoColors.systemGrey3.resolveFrom(context),
            ),
        ],
      ),
    );
  }
}
