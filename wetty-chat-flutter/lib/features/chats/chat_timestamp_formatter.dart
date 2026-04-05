import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

String formatChatMessageTime(BuildContext context, DateTime? timestamp) {
  if (timestamp == null) return '';
  return _timeFormatter(context).format(timestamp.toLocal());
}

String? formatChatListTimestamp(BuildContext context, DateTime? timestamp) {
  if (timestamp == null) return null;

  final localTimestamp = timestamp.toLocal();
  if (_isSameCalendarDay(localTimestamp, DateTime.now())) {
    return _timeFormatter(context).format(localTimestamp);
  }

  return DateFormat.Md(_localeName(context)).format(localTimestamp);
}

bool _isSameCalendarDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

DateFormat _timeFormatter(BuildContext context) {
  final localeName = _localeName(context);
  if (MediaQuery.of(context).alwaysUse24HourFormat) {
    return DateFormat.Hm(localeName);
  }

  return DateFormat.jm(localeName);
}

String _localeName(BuildContext context) =>
    Localizations.localeOf(context).toLanguageTag();
