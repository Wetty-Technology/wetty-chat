import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

Future<T?> showAdaptiveCupertinoPopup<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  double compactHeightFactor = 0.5,
  double regularBreakpoint = 600,
  double regularMaxWidth = 520,
  double regularMaxHeight = 680,
}) {
  return showCupertinoModalPopup<T>(
    context: context,
    builder: (context) => _AdaptiveCupertinoPopupFrame(
      compactHeightFactor: compactHeightFactor,
      regularBreakpoint: regularBreakpoint,
      regularMaxWidth: regularMaxWidth,
      regularMaxHeight: regularMaxHeight,
      child: builder(context),
    ),
  );
}

class _AdaptiveCupertinoPopupFrame extends StatelessWidget {
  const _AdaptiveCupertinoPopupFrame({
    required this.compactHeightFactor,
    required this.regularBreakpoint,
    required this.regularMaxWidth,
    required this.regularMaxHeight,
    required this.child,
  });

  static const double _compactBorderRadius = 14;
  static const double _regularBorderRadius = 16;
  static const double _regularOuterMargin = 32;

  final double compactHeightFactor;
  final double regularBreakpoint;
  final double regularMaxWidth;
  final double regularMaxHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < regularBreakpoint) {
          return _buildCompact(context, constraints);
        }
        return _buildRegular(context, constraints);
      },
    );
  }

  Widget _buildCompact(BuildContext context, BoxConstraints constraints) {
    final height = constraints.maxHeight * compactHeightFactor;
    return Align(
      alignment: Alignment.bottomCenter,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(_compactBorderRadius),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground.resolveFrom(context),
          ),
          child: SizedBox(
            width: constraints.maxWidth,
            height: height,
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildRegular(BuildContext context, BoxConstraints constraints) {
    final width = math.min(
      regularMaxWidth,
      constraints.maxWidth - (_regularOuterMargin * 2),
    );
    final height = math.min(
      regularMaxHeight,
      constraints.maxHeight - (_regularOuterMargin * 2),
    );

    return SafeArea(
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_regularBorderRadius),
          child: CupertinoPopupSurface(
            isSurfacePainted: true,
            child: SizedBox(width: width, height: height, child: child),
          ),
        ),
      ),
    );
  }
}
