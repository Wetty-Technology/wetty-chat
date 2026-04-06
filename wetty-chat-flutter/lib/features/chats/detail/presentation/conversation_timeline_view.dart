import 'package:flutter/cupertino.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../domain/timeline_entry.dart';

typedef TimelineVisibleRangeCallback =
    void Function(int minIndex, int maxIndex);
typedef TimelineEntryBuilder =
    Widget Function(BuildContext context, TimelineEntry entry, int index);

class ConversationTimelineView extends StatelessWidget {
  const ConversationTimelineView({
    super.key,
    required this.entries,
    required this.itemScrollController,
    required this.itemPositionsListener,
    required this.onVisibleRangeChanged,
    required this.entryBuilder,
    this.initialScrollIndex,
    this.initialAlignment = 0,
    this.topPadding = 0,
    this.bottomPadding = 0,
  });

  final List<TimelineEntry> entries;
  final ItemScrollController itemScrollController;
  final ItemPositionsListener itemPositionsListener;
  final TimelineVisibleRangeCallback onVisibleRangeChanged;
  final TimelineEntryBuilder entryBuilder;
  final int? initialScrollIndex;
  final double initialAlignment;
  final double topPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (_) {
        final positions = itemPositionsListener.itemPositions.value;
        if (positions.isEmpty) {
          return false;
        }
        final minIndex = positions
            .map((item) => item.index)
            .reduce((left, right) => left < right ? left : right);
        final maxIndex = positions
            .map((item) => item.index)
            .reduce((left, right) => left > right ? left : right);
        onVisibleRangeChanged(minIndex, maxIndex);
        return false;
      },
      child: ScrollablePositionedList.builder(
        itemScrollController: itemScrollController,
        itemPositionsListener: itemPositionsListener,
        initialScrollIndex: initialScrollIndex ?? 0,
        initialAlignment: initialAlignment,
        padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
        itemCount: entries.length,
        itemBuilder: (context, index) =>
            entryBuilder(context, entries[index], index),
      ),
    );
  }
}
