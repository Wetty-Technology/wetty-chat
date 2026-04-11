import 'package:flutter/cupertino.dart';

import '../../../../app/theme/style_config.dart';

class PreviewHeader extends StatelessWidget {
  const PreviewHeader({super.key, this.packName});

  final String? packName;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      height: 52,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.separator, width: 0.5)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (packName != null)
            Text(
              packName!,
              style: appTitleTextStyle(
                context,
                fontSize: AppFontSizes.appTitle,
              ),
            ),
          Positioned(
            right: 8,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.of(context).pop(),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: colors.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.xmark,
                  size: 14,
                  color: colors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
