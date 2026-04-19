class TimelineViewportEffect {
  const TimelineViewportEffect({
    required this.target,
    required this.alignment,
    this.resetToCenterOrigin = false,
    this.highlight = false,
  });

  const TimelineViewportEffect.revealBottom({
    this.alignment = TimelineViewportAlignment.bottom,
    this.resetToCenterOrigin = false,
  }) : target = null,
       highlight = false;

  const TimelineViewportEffect.resetToCenterOrigin({
    this.alignment = TimelineViewportAlignment.center,
    this.highlight = false,
  }) : target = null,
       resetToCenterOrigin = true;

  const TimelineViewportEffect.revealMessage(
    this.target, {
    this.alignment = TimelineViewportAlignment.center,
    this.resetToCenterOrigin = false,
    this.highlight = false,
  });

  /// `null` means the live-edge / bottom sentinel.
  final String? target;
  final TimelineViewportAlignment alignment;
  final bool resetToCenterOrigin;
  final bool highlight;

  bool get isBottomTarget => target == null && !resetToCenterOrigin;
}

enum TimelineViewportAlignment { top, center, bottom }
