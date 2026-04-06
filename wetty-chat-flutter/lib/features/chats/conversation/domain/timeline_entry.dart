import 'conversation_message.dart';

sealed class TimelineEntry {
  const TimelineEntry(this.key);

  final String key;
}

class TimelineMessageEntry extends TimelineEntry {
  TimelineMessageEntry(this.message) : super(message.stableKey);

  final ConversationMessage message;
}

class TimelineDateSeparatorEntry extends TimelineEntry {
  TimelineDateSeparatorEntry({required this.day})
    : super('date:${day.toIso8601String()}');

  final DateTime day;
}

class TimelineUnreadMarkerEntry extends TimelineEntry {
  const TimelineUnreadMarkerEntry() : super('meta:unread');
}

class TimelineHistoryGapOlderEntry extends TimelineEntry {
  const TimelineHistoryGapOlderEntry() : super('meta:history-gap-older');
}

class TimelineHistoryGapNewerEntry extends TimelineEntry {
  const TimelineHistoryGapNewerEntry() : super('meta:history-gap-newer');
}

class TimelineLoadingOlderEntry extends TimelineEntry {
  const TimelineLoadingOlderEntry() : super('meta:loading-older');
}

class TimelineLoadingNewerEntry extends TimelineEntry {
  const TimelineLoadingNewerEntry() : super('meta:loading-newer');
}
