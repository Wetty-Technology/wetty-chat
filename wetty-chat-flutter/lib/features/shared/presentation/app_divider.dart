import 'package:flutter/cupertino.dart';

/// Cupertino-style thin separator line.
class AppDivider extends StatelessWidget {
  const AppDivider({super.key, this.height = 0.5, this.color});
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: color ?? CupertinoColors.separator.resolveFrom(context),
    );
  }
}
