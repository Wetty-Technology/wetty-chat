import 'package:flutter/cupertino.dart';

import '../../../app/theme/style_config.dart';
import '../../../core/settings/app_settings_store.dart';

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

class MessageFontSizeSlider extends StatefulWidget {
  const MessageFontSizeSlider({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final double value;
  final ValueChanged<double> onChanged;

  static const double _trackInset = 8;
  static const double _thumbRadius = 10;
  static const double _markerHeight = 8;
  static const double _markerWidth = 3;
  static const double _trackHeight = 2;

  @override
  State<MessageFontSizeSlider> createState() => _MessageFontSizeSliderState();
}

class _MessageFontSizeSliderState extends State<MessageFontSizeSlider> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = CupertinoColors.systemBackground.resolveFrom(
      context,
    );
    final inactiveColor = CupertinoColors.systemGrey4.resolveFrom(context);
    final activeColor = CupertinoColors.activeBlue.resolveFrom(context);
    final markerCount = AppSettingsStore.chatMessageFontSizeSteps;
    final min = AppSettingsStore.minChatMessageFontSize;
    final max = AppSettingsStore.maxChatMessageFontSize;
    final sliderValue = (_dragValue ?? widget.value).clamp(min, max);

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 28,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final sliderWidth = constraints.maxWidth;
              final trackStart = MessageFontSizeSlider._trackInset;
              final trackEnd =
                  sliderWidth - MessageFontSizeSlider._trackInset;
              final markerStart =
                  MessageFontSizeSlider._trackInset +
                  MessageFontSizeSlider._thumbRadius;
              final markerEnd =
                  sliderWidth -
                  MessageFontSizeSlider._trackInset -
                  MessageFontSizeSlider._thumbRadius;
              final markerStep = markerCount > 1
                  ? (markerEnd - markerStart) / (markerCount - 1)
                  : 0.0;
              final leftMaskWidth = (markerStart -
                      (MessageFontSizeSlider._markerWidth / 2) -
                      trackStart)
                  .clamp(
                    0.0,
                    sliderWidth,
                  );
              final rightMaskLeft =
                  (markerEnd + (MessageFontSizeSlider._markerWidth / 2)).clamp(
                0.0,
                sliderWidth,
              );
              final rightMaskWidth = (trackEnd - rightMaskLeft).clamp(
                0.0,
                sliderWidth,
              );
              const sliderHeight = 28.0;

              return Stack(
                alignment: Alignment.center,
                children: [
                  IgnorePointer(
                    child: Stack(
                      children: [
                        ...List.generate(markerCount, (index) {
                          final markerValue = min + index;
                          final isHighlighted = markerValue <= sliderValue;
                          final markerCenter = markerStart + markerStep * index;
                          return Positioned(
                            left: markerCenter -
                                (MessageFontSizeSlider._markerWidth / 2),
                            top:
                                (sliderHeight -
                                        MessageFontSizeSlider._markerHeight) /
                                    2,
                            child: Container(
                              width: MessageFontSizeSlider._markerWidth,
                              height: MessageFontSizeSlider._markerHeight,
                              decoration: BoxDecoration(
                                color: isHighlighted
                                    ? activeColor
                                    : inactiveColor,
                                borderRadius: BorderRadius.circular(
                                  MessageFontSizeSlider._markerWidth,
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  Positioned.fill(
                    child: CupertinoSlider(
                      min: min,
                      max: max,
                      value: sliderValue,
                      activeColor: activeColor,
                      thumbColor: CupertinoColors.white,
                      onChangeStart: (_) {
                        setState(() {
                          _dragValue = sliderValue;
                        });
                      },
                      onChanged: (nextValue) {
                        setState(() {
                          _dragValue = nextValue;
                        });
                        widget.onChanged(nextValue);
                      },
                      onChangeEnd: (_) {
                        setState(() {
                          _dragValue = null;
                        });
                      },
                    ),
                  ),
                  IgnorePointer(
                    child: Stack(
                      children: [
                        if (leftMaskWidth > 0)
                          Positioned(
                            left: trackStart,
                            top:
                                (sliderHeight -
                                        MessageFontSizeSlider._trackHeight) /
                                    2,
                            child: Container(
                              width: leftMaskWidth,
                              height: MessageFontSizeSlider._trackHeight,
                              color: backgroundColor,
                            ),
                          ),
                        if (rightMaskWidth > 0)
                          Positioned(
                            left: rightMaskLeft,
                            top:
                                (sliderHeight -
                                        MessageFontSizeSlider._trackHeight) /
                                    2,
                            child: Container(
                              width: rightMaskWidth,
                              height: MessageFontSizeSlider._trackHeight,
                              color: backgroundColor,
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
        // the hint text under slider
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Small',
                  style: appSecondaryTextStyle(
                    context,
                    fontSize: AppFontSizes.meta,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Default',
                  textAlign: TextAlign.center,
                  style: appSecondaryTextStyle(
                    context,
                    fontSize: AppFontSizes.meta,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Large',
                  textAlign: TextAlign.right,
                  style: appSecondaryTextStyle(
                    context,
                    fontSize: AppFontSizes.meta,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
