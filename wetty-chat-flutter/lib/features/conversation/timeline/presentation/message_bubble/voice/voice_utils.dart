import 'dart:math' as math;

const double voiceBubbleHorizontalPadding = 24;
const double voiceWaveformButtonSize = 32;
const double voiceWaveformGap = 10;
const double voiceWaveformMaxWidth = 173;
const double voiceUniformWaveformWidth = voiceWaveformMaxWidth;

String formatVoiceDuration(Duration? duration) {
  if (duration == null) {
    return '--:--';
  }
  final totalSeconds = duration.inSeconds;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

Duration clampDuration(Duration value, Duration min, Duration max) {
  if (value < min) {
    return min;
  }
  if (value > max) {
    return max;
  }
  return value;
}

double progressFor(Duration position, Duration duration) {
  if (duration <= Duration.zero) {
    return 0;
  }
  return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
}

Duration positionFromDx(double dx, double width, Duration duration) {
  if (width <= 0 || duration <= Duration.zero) {
    return Duration.zero;
  }
  final ratio = (dx / width).clamp(0.0, 1.0);
  return Duration(milliseconds: (duration.inMilliseconds * ratio).round());
}

List<int> visibleSamplesForWaveform(List<int> samples, int targetCount) {
  if (samples.isEmpty || targetCount <= 0) {
    return const <int>[];
  }
  if (samples.length == targetCount) {
    return samples;
  }

  return List<int>.generate(targetCount, (index) {
    final start = (index * samples.length / targetCount).floor();
    final end = math.max(
      start + 1,
      ((index + 1) * samples.length / targetCount).ceil(),
    );
    var peak = 0;
    for (var sampleIndex = start; sampleIndex < end; sampleIndex++) {
      peak = math.max(peak, samples[sampleIndex]);
    }
    return peak;
  }, growable: false);
}

Duration resolveVoiceDuration({
  Duration? attachmentDuration,
  Duration? playbackDuration,
  Duration? resolvedDuration,
  required Duration? waveformDuration,
}) {
  final candidates = <Duration?>[
    attachmentDuration,
    playbackDuration,
    resolvedDuration,
    waveformDuration,
  ];
  for (final candidate in candidates) {
    if (candidate != null && candidate > Duration.zero) {
      return candidate;
    }
  }
  return attachmentDuration ??
      playbackDuration ??
      resolvedDuration ??
      waveformDuration ??
      Duration.zero;
}

double voiceBubbleWidthForWaveformWidth(double waveformWidth) {
  return voiceBubbleHorizontalPadding +
      voiceWaveformButtonSize +
      voiceWaveformGap +
      waveformWidth;
}

double voiceBubbleMinWidthForMetaRow(double statusTextWidth, double metaWidth) {
  return voiceBubbleHorizontalPadding + statusTextWidth + metaWidth;
}

double voiceBubbleWidth({
  required double waveformWidth,
  required double statusTextWidth,
  required double metaWidth,
  double? maxBubbleWidth,
}) {
  final computedWidth = math.max(
    voiceBubbleWidthForWaveformWidth(waveformWidth),
    voiceBubbleMinWidthForMetaRow(statusTextWidth, metaWidth),
  );
  if (maxBubbleWidth == null) {
    return computedWidth;
  }
  return math.min(computedWidth, maxBubbleWidth);
}
