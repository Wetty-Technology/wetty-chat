import 'package:flutter/cupertino.dart';

class AppFontSizes {
  const AppFontSizes._();

  static const double appTitle = 17;
  static const double sectionTitle = 17;
  static const double chatEntryTitle = 16;
  static const double body = 14;
  static const double bodySmall = 13;
  static const double meta = 12;
  static const double unreadBadge = 11;

  static const double bubbleText = 16;
  static const double bubbleMeta = 11;
  static const double replyQuote = 14;
}

class IconSizes {
  const IconSizes._();

  static const double iconSize = 22;
}

const appBaseTextStyle = TextStyle(
  color: CupertinoColors.label,
  fontWeight: FontWeight.w400,
);

const appCupertinoTheme = CupertinoThemeData(
  // TODO: follow the system settings
  brightness: Brightness.light,
  textTheme: CupertinoTextThemeData(
    textStyle: appBaseTextStyle,
    actionTextStyle: TextStyle(
      color: CupertinoColors.activeBlue,
      fontWeight: FontWeight.w400,
    ),
    tabLabelTextStyle: appBaseTextStyle,
    navTitleTextStyle: TextStyle(
      color: CupertinoColors.label,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
    navLargeTitleTextStyle: TextStyle(
      color: CupertinoColors.label,
      fontWeight: FontWeight.w700,
    ),
    navActionTextStyle: TextStyle(
      color: CupertinoColors.activeBlue,
      fontWeight: FontWeight.w400,
    ),
    pickerTextStyle: appBaseTextStyle,
    dateTimePickerTextStyle: appBaseTextStyle,
  ),
);

TextStyle appTextStyle(
  BuildContext context, {
  Color? color,
  double? fontSize,
  FontWeight? fontWeight,
  double? height,
  FontStyle? fontStyle,
  TextDecoration? decoration,
  Color? decorationColor,
}) {
  return CupertinoTheme.of(context).textTheme.textStyle.copyWith(
    color: color ?? CupertinoColors.label.resolveFrom(context),
    fontSize: fontSize ?? AppFontSizes.body,
    fontWeight: fontWeight,
    height: height,
    fontStyle: fontStyle,
    decoration: decoration,
    decorationColor: decorationColor,
  );
}

TextStyle appSecondaryTextStyle(
  BuildContext context, {
  double? fontSize,
  FontWeight? fontWeight,
  double? height,
  FontStyle? fontStyle,
}) {
  return appTextStyle(
    context,
    color: CupertinoColors.secondaryLabel.resolveFrom(context),
    fontSize: fontSize,
    fontWeight: fontWeight,
    height: height,
    fontStyle: fontStyle,
  );
}

TextStyle appTitleTextStyle(
  BuildContext context, {
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
}) {
  return appTextStyle(
    context,
    color: color,
    fontSize: fontSize,
    fontWeight: fontWeight ?? FontWeight.w600,
  );
}

TextStyle appBubbleTextStyle(
  BuildContext context, {
  Color? color,
  double? fontSize,
  FontWeight? fontWeight,
  double? height,
  FontStyle? fontStyle,
}) {
  return appTextStyle(
    context,
    color: color,
    fontSize: fontSize,
    fontWeight: fontWeight,
    height: height,
    fontStyle: fontStyle,
  );
}

TextStyle appBubbleMetaTextStyle(
  BuildContext context, {
  Color? color,
  double? fontSize,
  FontWeight? fontWeight,
}) {
  return appBubbleTextStyle(
    context,
    color: color ?? CupertinoColors.secondaryLabel.resolveFrom(context),
    fontSize: fontSize,
    fontWeight: fontWeight,
  );
}

TextStyle appOnDarkTextStyle(
  BuildContext context, {
  double? fontSize,
  FontWeight? fontWeight,
  Color? color,
}) {
  return appTextStyle(
    context,
    color: color ?? CupertinoColors.white,
    fontSize: fontSize,
    fontWeight: fontWeight,
  );
}

TextStyle appChatEntryTitleTextStyle(
  BuildContext context, {
  Color? color,
  FontWeight? fontWeight,
}) {
  return appTextStyle(
    context,
    color: color,
    fontSize: AppFontSizes.chatEntryTitle,
    fontWeight: fontWeight ?? FontWeight.w600,
  );
}

TextStyle appSectionTitleTextStyle(
  BuildContext context, {
  Color? color,
  FontWeight? fontWeight,
}) {
  return appTextStyle(
    context,
    color: color,
    fontSize: AppFontSizes.sectionTitle,
    fontWeight: fontWeight ?? FontWeight.w600,
  );
}
