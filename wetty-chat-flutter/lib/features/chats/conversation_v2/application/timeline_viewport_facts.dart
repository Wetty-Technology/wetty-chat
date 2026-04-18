class TimelineViewportFacts {
  const TimelineViewportFacts({
    required this.isNearTop,
    required this.isNearBottom,
    required this.pixels,
    required this.maxScrollExtent,
  });

  final bool isNearTop;
  final bool isNearBottom;
  final double pixels;
  final double maxScrollExtent;
}
