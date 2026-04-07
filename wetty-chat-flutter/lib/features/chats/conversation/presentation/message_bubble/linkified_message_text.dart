import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';

class LinkifiedMessageText extends StatelessWidget {
  const LinkifiedMessageText({
    super.key,
    required this.text,
    required this.textStyle,
    required this.linkColor,
    required this.trailingSpacerWidth,
  });

  final String text;
  final TextStyle textStyle;
  final Color linkColor;
  final double trailingSpacerWidth;

  static final RegExp _urlRegex = RegExp(
    r'(https?://[^\s<>]+|www\.[^\s<>]+)',
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
    final spans = <InlineSpan>[];
    var lastEnd = 0;
    for (final match in _urlRegex.allMatches(value)) {
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: value.substring(lastEnd, match.start),
            style: baseStyle,
          ),
        );
      }

      final url = match.group(0)!;
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
}
