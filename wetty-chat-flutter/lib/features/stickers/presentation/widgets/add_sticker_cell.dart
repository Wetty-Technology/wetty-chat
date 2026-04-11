import 'package:flutter/cupertino.dart';

import '../../../../app/theme/style_config.dart';

class AddStickerCell extends StatelessWidget {
  const AddStickerCell({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedBorderPainter(color: colors.separator),
        child: Center(
          child: Icon(
            CupertinoIcons.add,
            size: 32,
            color: colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final rRect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(8),
    );
    final path = Path()..addRRect(rRect);

    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, end.clamp(0, metric.length)),
          paint,
        );
        distance = end + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      color != oldDelegate.color;
}
