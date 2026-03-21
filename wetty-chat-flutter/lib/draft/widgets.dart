import 'package:flutter/cupertino.dart';

/// Cupertino-style thin separator line.
class Divider extends StatelessWidget {
  const Divider({super.key, this.height = 1, this.color});
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
