import 'package:chahua/app/theme/style_config.dart';
import 'package:flutter/cupertino.dart';

class VoiceUnavailableView extends StatelessWidget {
  const VoiceUnavailableView({
    super.key,
    required this.statusText,
    required this.icon,
    required this.metaColor,
  });

  final String statusText;
  final Widget icon;
  final Color metaColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 32, height: 32, child: Center(child: icon)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            statusText,
            style: appSecondaryTextStyle(
              context,
              fontSize: AppFontSizes.meta,
            ).copyWith(color: metaColor),
          ),
        ),
      ],
    );
  }
}
