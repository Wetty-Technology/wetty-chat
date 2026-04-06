import 'package:flutter/cupertino.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../models/conversation_models.dart';

class ConversationTimelineView extends StatelessWidget {
  const ConversationTimelineView({
    super.key,
    required this.entries,
    required this.itemScrollController,
    required this.scrollOffsetController,
    required this.itemPositionsListener,
    required this.itemBuilder,
    this.padding = EdgeInsets.zero,
    this.reverse = true,
  });

  final List<TimelineEntry> entries;
  final ItemScrollController itemScrollController;
  final ScrollOffsetController scrollOffsetController;
  final ItemPositionsListener itemPositionsListener;
  final Widget Function(BuildContext context, int index, TimelineEntry entry)
  itemBuilder;
  final EdgeInsets padding;
  final bool reverse;

  @override
  Widget build(BuildContext context) {
    return ScrollablePositionedList.builder(
      itemScrollController: itemScrollController,
      scrollOffsetController: scrollOffsetController,
      itemPositionsListener: itemPositionsListener,
      reverse: reverse,
      padding: padding,
      itemCount: entries.length,
      itemBuilder: (context, index) =>
          itemBuilder(context, index, entries[index]),
    );
  }
}
