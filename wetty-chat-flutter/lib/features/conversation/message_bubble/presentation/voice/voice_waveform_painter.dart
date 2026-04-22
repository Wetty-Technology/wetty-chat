import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

class VoiceWaveformPainter extends CustomPainter {
  const VoiceWaveformPainter({
    required this.samples,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  static const double barWidth = 3;
  static const double gap = 2;

  final List<int> samples;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty || size.width <= 0) {
      return;
    }

    final playedCount = (samples.length * progress).round();
    const radius = Radius.circular(barWidth / 2);
    final baseline = size.height / 2;

    for (var index = 0; index < samples.length; index++) {
      final x = index * (barWidth + gap);
      final normalized = (samples[index] / 255).clamp(0.0, 1.0);
      final barHeight = math.max(6.0, size.height * (0.2 + normalized * 0.8));
      final rect = Rect.fromLTWH(
        x,
        baseline - barHeight / 2,
        barWidth,
        barHeight,
      );
      final paint = Paint()
        ..color = index < playedCount ? activeColor : inactiveColor;
      canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), paint);
    }
  }

  @override
  bool shouldRepaint(covariant VoiceWaveformPainter oldDelegate) {
    return oldDelegate.samples != samples ||
        oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}

class VoicePlaybackIcon extends StatelessWidget {
  const VoicePlaybackIcon({
    super.key,
    required this.phaseKind,
    required this.iconColor,
  });

  final VoicePlaybackIconKind phaseKind;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    switch (phaseKind) {
      case VoicePlaybackIconKind.loading:
        return CupertinoActivityIndicator(color: iconColor);
      case VoicePlaybackIconKind.playing:
        return Icon(CupertinoIcons.pause_fill, size: 18, color: iconColor);
      case VoicePlaybackIconKind.error:
        return Icon(
          CupertinoIcons.exclamationmark_triangle_fill,
          size: 18,
          color: CupertinoColors.systemRed.resolveFrom(context),
        );
      case VoicePlaybackIconKind.play:
        return Icon(CupertinoIcons.play_fill, size: 18, color: iconColor);
    }
  }
}

enum VoicePlaybackIconKind { loading, playing, error, play }
