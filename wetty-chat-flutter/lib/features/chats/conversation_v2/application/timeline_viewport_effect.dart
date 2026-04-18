class TimelineViewportEffect {
  const TimelineViewportEffect({
    required this.target,
    required this.alignment,
    this.highlight = false,
  });

  const TimelineViewportEffect.revealBottom({
    this.alignment = TimelineViewportAlignment.bottom,
  }) : target = null,
       highlight = false;

  const TimelineViewportEffect.revealMessage(
    this.target, {
    this.alignment = TimelineViewportAlignment.center,
    this.highlight = false,
  });

  /// `null` means the live-edge / bottom sentinel.
  final String? target;
  final TimelineViewportAlignment alignment;
  final bool highlight;

  bool get isBottomTarget => target == null;
}

enum TimelineViewportAlignment { top, center, bottom }
