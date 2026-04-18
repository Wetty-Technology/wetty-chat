class TimelineViewportEffect {
  const TimelineViewportEffect._({required this.type});

  const TimelineViewportEffect.revealBottom()
    : this._(type: TimelineViewportEffectType.revealBottom);

  final TimelineViewportEffectType type;
}

enum TimelineViewportEffectType { revealBottom }
