import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/features/shared/model/message/message.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/bubble_theme_v2.dart';

class LinkifiedText extends StatelessWidget {
  const LinkifiedText({
    super.key,
    required this.text,
    required this.textStyle,
    required this.mentions,
    required this.currentUserId,
    this.onTapMention,
  });

  final String text;
  final TextStyle textStyle;
  final List<MentionInfo> mentions;
  final int? currentUserId;
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
    final theme = BubbleThemeV2.of(context);
    return Text.rich(
      TextSpan(
        children: [
          ..._buildLinkedSpans(context, theme),
          WidgetSpan(child: SizedBox(width: theme.timeSpacerWidth, height: 14)),
        ],
      ),
    );
  }

  List<InlineSpan> _buildLinkedSpans(
    BuildContext context,
    BubbleThemeV2 theme,
  ) {
    final mentionsById = <int, MentionInfo>{
      for (final mention in mentions) mention.uid: mention,
    };
    final mentionTextColor = theme.isMe
        ? CupertinoColors.white
        : CupertinoColors.activeBlue.resolveFrom(context);
    final mentionBackgroundColor = theme.isMe
        ? CupertinoColors.white.withAlpha(46)
        : CupertinoColors.activeBlue.resolveFrom(context).withAlpha(26);
    final selfMentionBackgroundColor = theme.isMe
        ? CupertinoColors.white.withAlpha(71)
        : CupertinoColors.activeBlue.resolveFrom(context).withAlpha(51);
    final spans = <InlineSpan>[];
    var lastEnd = 0;
    for (final match in _tokenRegex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, match.start),
            style: textStyle,
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
        final mentionTap = theme.isInteractive && onTapMention != null
            ? () => onTapMention!(mentionUid, mention)
            : null;
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: mentionTap,
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
                  style: textStyle.copyWith(
                    color: mentionTextColor,
                    fontSize: (textStyle.fontSize ?? 14) * 0.9,
                    fontWeight: AppFontWeights.semibold,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        );
      } else {
        final url = token;
        final recognizer = theme.isInteractive
            ? (TapGestureRecognizer()
                ..onTap = () {
                  final uri = url.startsWith('http') ? url : 'https://$url';
                  launchUrl(
                    Uri.parse(uri),
                    mode: LaunchMode.externalApplication,
                  );
                })
            : null;
        spans.add(
          TextSpan(
            text: url,
            style: textStyle.copyWith(
              color: theme.linkColor,
              decoration: TextDecoration.underline,
              decorationColor: theme.linkColor,
            ),
            recognizer: recognizer,
          ),
        );
      }
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: textStyle));
    }
    if (spans.isEmpty) {
      spans.add(TextSpan(text: text, style: textStyle));
    }
    return spans;
  }

  int? _parseMentionUid(String token) {
    final match = _mentionRegex.firstMatch(token);
    return int.tryParse(match?.group(1) ?? '');
  }
}
