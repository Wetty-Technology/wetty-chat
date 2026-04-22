import 'package:chahua/app/theme/style_config.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../bubble_theme_v2.dart';

const double senderHeaderBodyGap = 4;
const double _senderHeaderBadgeGap = 4;
const double _senderHeaderBadgeSize = 11;

class SenderHeader extends StatelessWidget {
  const SenderHeader({super.key, required this.senderName, this.gender = 0});

  static const String _maleBadgeSvg =
      '<svg viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg"><path d="M896.35739 415.483806V127.690194h-287.794636l107.116623 107.116623-108.319007 108.316961c-49.568952-34.997072-110.052488-55.56348-175.344541-55.56348-168.101579 0-304.374242 136.273686-304.374242 304.374242s136.273686 304.374243 304.374242 304.374243S736.390072 760.03612 736.390072 591.93454c0-61.631686-18.3356-118.972649-49.824779-166.901241L796.238135 315.365574l100.119255 100.118232zM432.015829 800.190655c-115.015523 0-208.256114-93.240591-208.256115-208.256115s93.240591-208.256114 208.256115-208.256114 208.256114 93.240591 208.256114 208.256114-93.240591 208.256114-208.256114 208.256115z" fill="#CCCCCC"/></svg>';
  static const String _femaleBadgeSvg =
      '<svg viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg"><path d="M815.562249 368.20706c0-167.652348-135.909389-303.56276-303.562761-303.562761S208.436728 200.554712 208.436728 368.20706c0 151.34187 110.7555 276.800233 255.632121 299.782667v67.687612H304.299029v95.862301h159.76982v127.816061h95.862302V831.53964h159.76982v-95.862301H559.930127v-67.687612c144.875598-22.982434 255.632121-148.440797 255.632122-299.782667z m-511.26322 0c0-114.708532 92.991927-207.700459 207.700459-207.700459s207.700459 92.991927 207.700459 207.700459-92.991927 207.700459-207.700459 207.700459-207.700459-92.991927-207.700459-207.700459z" fill="#CCCCCC"/></svg>';

  final String senderName;
  final int gender;

  @override
  Widget build(BuildContext context) {
    final theme = BubbleThemeV2.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            senderName,
            style: appBubbleTextStyle(
              context,
              fontWeight: FontWeight.w700,
              fontSize: AppFontSizes.body,
              color: theme.textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (gender == 1 || gender == 2) ...[
          const SizedBox(width: _senderHeaderBadgeGap),
          Opacity(
            opacity: 0.9,
            child: SvgPicture.string(
              gender == 1 ? _maleBadgeSvg : _femaleBadgeSvg,
              width: _senderHeaderBadgeSize,
              height: _senderHeaderBadgeSize,
              colorFilter: ColorFilter.mode(
                gender == 1 ? const Color(0xFF4A90E2) : const Color(0xFFE86DA8),
                BlendMode.srcIn,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
