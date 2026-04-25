import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../../l10n/app_localizations.dart';

/// Formats a message timestamp as local time (HH:mm or h:mm AM/PM).
String formatChatMessageTime(BuildContext context, DateTime? timestamp) {
  if (timestamp == null) return '';
  return _timeFormatter(context).format(timestamp.toLocal());
}

/// Formats a timestamp for chat list / thread list display.
///
/// Matches PWA behavior:
/// - Same day, < 60 min: relative minutes ("5 minutes ago")
/// - Same day, >= 60 min: relative hours ("2 hours ago")
/// - Different day, same year: short date ("Jan 15")
/// - Different year: full date ("Jan 15, 2025")
String? formatChatListTimestamp(BuildContext context, DateTime? timestamp) {
  if (timestamp == null) return null;

  final l10n = AppLocalizations.of(context)!;
  final localTimestamp = timestamp.toLocal();
  final now = DateTime.now();

  if (_isSameCalendarDay(localTimestamp, now)) {
    final diffMs = now.difference(localTimestamp).inMinutes;
    final diffMins = max(1, diffMs);

    if (diffMins < 60) {
      return l10n.relativeMinutes(diffMins);
    }
    return l10n.relativeHours(diffMins ~/ 60);
  }

  final locale = _localeName(context);
  if (localTimestamp.year == now.year) {
    return DateFormat.MMMd(locale).format(localTimestamp);
  }
  return DateFormat.yMMMd(locale).format(localTimestamp);
}

/// Formats a date for the conversation date separator.
///
/// - Today: "Today"
/// - Yesterday: "Yesterday"
/// - Same year: short date ("Jan 15")
/// - Different year: full date ("Jan 15, 2025")
String formatDateSeparator(BuildContext context, DateTime day) {
  final l10n = AppLocalizations.of(context)!;
  final now = DateTime.now();

  if (_isSameCalendarDay(day, now)) {
    return l10n.dateToday;
  }

  final yesterday = DateTime(now.year, now.month, now.day - 1);
  if (_isSameCalendarDay(day, yesterday)) {
    return l10n.dateYesterday;
  }

  final locale = _localeName(context);
  if (day.year == now.year) {
    return DateFormat.MMMd(locale).format(day);
  }
  return DateFormat.yMMMd(locale).format(day);
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
