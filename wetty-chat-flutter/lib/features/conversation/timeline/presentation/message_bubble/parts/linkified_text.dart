import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:chahua/features/chats/models/message_models.dart';

class LinkifiedText extends StatelessWidget {
  const LinkifiedText({
    super.key,
    required this.text,
    required this.textStyle,
    required this.linkColor,
    required this.mentions,
    required this.currentUserId,
    required this.mentionTextColor,
    required this.mentionBackgroundColor,
    required this.selfMentionBackgroundColor,
    required this.trailingSpacerWidth,
    this.onTapMention,
  });

  final String text;
  final TextStyle textStyle;
  final Color linkColor;
  final List<MentionInfo> mentions;
  final int? currentUserId;
  final Color mentionTextColor;
  final Color mentionBackgroundColor;
  final Color selfMentionBackgroundColor;
  final double trailingSpacerWidth;
  final void Function(int uid, MentionInfo? mention)? onTapMention;

  static final RegExp _mentionRegex = RegExp(r'@\[uid:(\d+)\]');

  static final RegExp _urlRegex = RegExp(
    r'(https?://[^\s<>]+|www\.[^\s<>]+)',
    caseSensitive: false,
  );

  static final RegExp _tokenRegex = RegExp(
    '${_mentionRegex.pattern}|${_urlRegex.pattern}',
    caseSensitive: false,
  );

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          ..._buildLinkedSpans(text, textStyle, linkColor),
          WidgetSpan(child: SizedBox(width: trailingSpacerWidth, height: 14)),
        ],
      ),
    );
  }

  List<InlineSpan> _buildLinkedSpans(
    String value,
    TextStyle baseStyle,
    Color resolvedLinkColor,
  ) {
    final mentionsById = <int, MentionInfo>{
      for (final mention in mentions) mention.uid: mention,
    };
    final spans = <InlineSpan>[];
    var lastEnd = 0;
    for (final match in _tokenRegex.allMatches(value)) {
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: value.substring(lastEnd, match.start),
            style: baseStyle,
          ),
        );
      }

      final token = match.group(0)!;
      final mentionUid = _parseMentionUid(token);
      if (mentionUid != null) {
        final mention = mentionsById[mentionUid];
        final username = mention?.username;
        final visibleText =
            '@${(username != null && username.isNotEmpty) ? username : 'User $mentionUid'}';
        final isSelf = currentUserId != null && mentionUid == currentUserId;
        final recognizer = onTapMention == null
            ? null
            : (TapGestureRecognizer()
                ..onTap = () => onTapMention!(mentionUid, mention));
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: recognizer?.onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelf
                      ? selfMentionBackgroundColor
                      : mentionBackgroundColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  visibleText,
                  textScaler: TextScaler.noScaling,
                  style: baseStyle.copyWith(
                    color: mentionTextColor,
                    fontSize: (baseStyle.fontSize ?? 14) * 0.9,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        );
      } else {
        final url = token;
        final recognizer = TapGestureRecognizer()
          ..onTap = () {
            final uri = url.startsWith('http') ? url : 'https://$url';
            launchUrl(Uri.parse(uri), mode: LaunchMode.externalApplication);
          };
        spans.add(
          TextSpan(
            text: url,
            style: baseStyle.copyWith(
              color: resolvedLinkColor,
              decoration: TextDecoration.underline,
              decorationColor: resolvedLinkColor,
            ),
            recognizer: recognizer,
          ),
        );
      }
      lastEnd = match.end;
    }

    if (lastEnd < value.length) {
      spans.add(TextSpan(text: value.substring(lastEnd), style: baseStyle));
    }
    if (spans.isEmpty) {
      spans.add(TextSpan(text: value, style: baseStyle));
    }
    return spans;
  }

  int? _parseMentionUid(String token) {
    final match = _mentionRegex.firstMatch(token);
    return int.tryParse(match?.group(1) ?? '');
  }
}
