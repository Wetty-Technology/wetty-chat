import 'package:chahua/features/chats/models/message_models.dart';

class ComposerMentionEntry {
  const ComposerMentionEntry({
    required this.uid,
    required this.username,
    required this.start,
    required this.end,
  });

  final int uid;
  final String username;
  final int start;
  final int end;
}

class MentionTriggerMatch {
  const MentionTriggerMatch({required this.query, required this.triggerStart});

  final String query;
  final int triggerStart;
}

class HydratedComposerMentions {
  const HydratedComposerMentions({required this.text, required this.entries});

  final String text;
  final List<ComposerMentionEntry> entries;
}

final RegExp _mentionTokenRegex = RegExp(r'@\[uid:(\d+)\]');

MentionTriggerMatch? detectMentionTrigger(String text, int cursorPosition) {
  if (cursorPosition <= 0 || cursorPosition > text.length) {
    return null;
  }

  var index = cursorPosition - 1;
  while (index >= 0) {
    final character = text[index];
    if (_isWhitespace(character)) {
      return null;
    }
    if (character == '@') {
      if (index == 0 || _isWhitespace(text[index - 1])) {
        return MentionTriggerMatch(
          query: text.substring(index + 1, cursorPosition),
          triggerStart: index,
        );
      }
      return null;
    }
    index--;
  }
  return null;
}

List<ComposerMentionEntry> retainValidMentionEntries(
  String text,
  List<ComposerMentionEntry> entries,
) {
  return entries
      .where((entry) {
        if (entry.start < 0 ||
            entry.end > text.length ||
            entry.start >= entry.end) {
          return false;
        }
        return text.substring(entry.start, entry.end) == '@${entry.username}';
      })
      .toList(growable: false);
}

String convertComposerMentionsToWireFormat(
  String text,
  List<ComposerMentionEntry> entries,
) {
  if (entries.isEmpty) {
    return text;
  }

  var result = text;
  final sortedEntries = [...entries]
    ..sort((left, right) => right.start.compareTo(left.start));
  for (final entry in sortedEntries) {
    if (entry.start < 0 ||
        entry.end > result.length ||
        entry.start >= entry.end) {
      continue;
    }
    final displayMention = '@${entry.username}';
    if (result.substring(entry.start, entry.end) != displayMention) {
      continue;
    }
    result =
        '${result.substring(0, entry.start)}'
        '@[uid:${entry.uid}]'
        '${result.substring(entry.end)}';
  }
  return result;
}

HydratedComposerMentions hydrateComposerMentions(
  String text,
  List<MentionInfo> mentions,
) {
  if (text.isEmpty) {
    return const HydratedComposerMentions(
      text: '',
      entries: <ComposerMentionEntry>[],
    );
  }

  final usernamesById = <int, String>{};
  for (final mention in mentions) {
    final username = mention.username;
    if (username != null && username.isNotEmpty) {
      usernamesById[mention.uid] = username;
    }
  }

  final buffer = StringBuffer();
  final hydratedEntries = <ComposerMentionEntry>[];
  var lastEnd = 0;

  for (final match in _mentionTokenRegex.allMatches(text)) {
    if (match.start > lastEnd) {
      buffer.write(text.substring(lastEnd, match.start));
    }
    final uid = int.tryParse(match.group(1) ?? '');
    if (uid == null) {
      buffer.write(match.group(0));
      lastEnd = match.end;
      continue;
    }

    final username = usernamesById[uid] ?? 'User $uid';
    final displayText = '@$username';
    final start = buffer.length;
    buffer.write(displayText);
    hydratedEntries.add(
      ComposerMentionEntry(
        uid: uid,
        username: username,
        start: start,
        end: start + displayText.length,
      ),
    );
    lastEnd = match.end;
  }

  if (lastEnd < text.length) {
    buffer.write(text.substring(lastEnd));
  }

  return HydratedComposerMentions(
    text: buffer.toString(),
    entries: hydratedEntries,
  );
}

bool _isWhitespace(String value) => value.trim().isEmpty;
