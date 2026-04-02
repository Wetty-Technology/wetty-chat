import 'package:flutter/cupertino.dart';

import '../../../app/theme/style_config.dart';
import '../../../core/settings/app_settings_store.dart';

class SettingsSectionData {
  const SettingsSectionData({required this.title, required this.items});

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
  const SettingsSectionCard({super.key, required this.section});

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
  const SettingsActionRow({super.key, required this.item});

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

  static const double _horizontalPadding = 20;
  static const double _thumbRadius = 12;
  static const double _markerHeight = 8;
  static const double _markerWidth = 3;
  static const double _trackHeight = 2;

  @override
  State<MessageFontSizeSlider> createState() => _MessageFontSizeSliderState();
}

class _MessageFontSizeSliderState extends State<MessageFontSizeSlider> {
  double? _dragValue;

  double get _minValue => AppSettingsStore.minChatMessageFontSize;
  double get _maxValue => AppSettingsStore.maxChatMessageFontSize;
  int get _stepCount => AppSettingsStore.chatMessageFontSizeSteps;

  double _effectiveValue() => (_dragValue ?? widget.value).clamp(
    _minValue,
    _maxValue,
  );

  double _valueForIndex(int index) => _minValue + index;

  double _trackWidth(double width) =>
      (width - (MessageFontSizeSlider._horizontalPadding * 2)).clamp(1.0, width);

  double _normalizedPosition(double x, double width) {
    final trackWidth = _trackWidth(width);
    final raw = (x - MessageFontSizeSlider._horizontalPadding) / trackWidth;
    return raw.clamp(0.0, 1.0);
  }

  double _snappedValueForPosition(double x, double width) {
    final idx = (_normalizedPosition(x, width) * (_stepCount - 1))
        .round()
        .clamp(0, _stepCount - 1);
    return _valueForIndex(idx);
  }

  void _setDragValue(double value) {
    if (_dragValue == value) return;
    setState(() {
      _dragValue = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final inactiveColor = CupertinoColors.systemGrey4.resolveFrom(context);
    final activeColor = CupertinoColors.activeBlue.resolveFrom(context);
    final currentValue = _effectiveValue();

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 28,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final sliderWidth = constraints.maxWidth;
              final trackStart = MessageFontSizeSlider._horizontalPadding;
              final trackEnd =
                  sliderWidth - MessageFontSizeSlider._horizontalPadding;
              final markerStep = _stepCount > 1
                  ? (trackEnd - trackStart) / (_stepCount - 1)
                  : 0.0;
              final thumbCenter = trackStart +
                  (((currentValue - _minValue) / (_maxValue - _minValue)) *
                      (trackEnd - trackStart));
              const sliderHeight = 28.0;
              final trackTop =
                  (sliderHeight - MessageFontSizeSlider._trackHeight) / 2;
              final thumbTop =
                  (sliderHeight - (MessageFontSizeSlider._thumbRadius * 2)) / 2;

              return GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapDown: (details) {
                  final nextValue = _snappedValueForPosition(
                    details.localPosition.dx,
                    sliderWidth,
                  );
                  widget.onChanged(nextValue);
                },
                onHorizontalDragStart: (details) {
                  final nextValue = _snappedValueForPosition(
                    details.localPosition.dx,
                    sliderWidth,
                  );
                  _setDragValue(nextValue);
                  widget.onChanged(nextValue);
                },
                onHorizontalDragUpdate: (details) {
                  final nextValue = _snappedValueForPosition(
                    details.localPosition.dx,
                    sliderWidth,
                  );
                  _setDragValue(nextValue);
                  widget.onChanged(nextValue);
                },
                onHorizontalDragEnd: (_) {
                  setState(() {
                    _dragValue = null;
                  });
                },
                onHorizontalDragCancel: () {
                  setState(() {
                    _dragValue = null;
                  });
                },
                child: Stack(
                  children: [
                    Positioned(
                      left: trackStart,
                      top: trackTop,
                      child: Container(
                        width: trackEnd - trackStart,
                        height: MessageFontSizeSlider._trackHeight,
                        decoration: BoxDecoration(
                          color: inactiveColor,
                          borderRadius: BorderRadius.circular(
                            MessageFontSizeSlider._trackHeight,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: trackStart,
                      top: trackTop,
                      child: Container(
                        width: (thumbCenter - trackStart).clamp(
                          0.0,
                          trackEnd - trackStart,
                        ),
                        height: MessageFontSizeSlider._trackHeight,
                        decoration: BoxDecoration(
                          color: activeColor,
                          borderRadius: BorderRadius.circular(
                            MessageFontSizeSlider._trackHeight,
                          ),
                        ),
                      ),
                    ),
                    ...List.generate(_stepCount, (index) {
                      final markerValue = _valueForIndex(index);
                      final isHighlighted = markerValue <= currentValue;
                      final markerCenter = trackStart + markerStep * index;
                      return Positioned(
                        left: markerCenter -
                            (MessageFontSizeSlider._markerWidth / 2),
                        top:
                            (sliderHeight - MessageFontSizeSlider._markerHeight) /
                                2,
                        child: Container(
                          width: MessageFontSizeSlider._markerWidth,
                          height: MessageFontSizeSlider._markerHeight,
                          decoration: BoxDecoration(
                            color: isHighlighted ? activeColor : inactiveColor,
                            borderRadius: BorderRadius.circular(
                              MessageFontSizeSlider._markerWidth,
                            ),
                          ),
                        ),
                      );
                    }),
                    Positioned(
                      left: thumbCenter - MessageFontSizeSlider._thumbRadius,
                      top: thumbTop,
                      child: Container(
                        width: MessageFontSizeSlider._thumbRadius * 2,
                        height: MessageFontSizeSlider._thumbRadius * 2,
                        decoration: const BoxDecoration(
                          color: CupertinoColors.activeBlue,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
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
