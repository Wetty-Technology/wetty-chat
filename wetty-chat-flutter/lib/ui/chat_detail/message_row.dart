import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/api_config.dart';
import '../../data/models/message_models.dart';
import '../shared/settings_store.dart';

// ---------------------------------------------------------------------------
// MessageRow 鈥?message bubble with avatar, inline time, reply quote,
// swipe-to-reply gesture
// ---------------------------------------------------------------------------

class MessageRow extends StatefulWidget {
  const MessageRow({
    super.key,
    required this.message,
    this.isHighlighted = false,
    this.onLongPress,
    this.onReply,
    this.onTapReply,
    this.showSenderName = true,
    this.showAvatar = true,
  });

  final MessageItem message;
  final bool isHighlighted;
  final VoidCallback? onLongPress;
  final VoidCallback? onReply;
  final VoidCallback? onTapReply;
  final bool showSenderName;
  final bool showAvatar;

  @override
  State<MessageRow> createState() => _MessageRowState();
}

class _MessageRowState extends State<MessageRow>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0;
  bool _hasTriggeredReply = false;
  static const double _replyThreshold = 60;

  bool get _isMe {
    final currentUserId = curUserId;
    return currentUserId != null && widget.message.sender.uid == currentUserId;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dx).clamp(
        -_replyThreshold * 1.3,
        0,
      );
    });
    if (!_hasTriggeredReply && _dragOffset <= -_replyThreshold) {
      _hasTriggeredReply = true;
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_hasTriggeredReply) {
      widget.onReply?.call();
    }
    _hasTriggeredReply = false;
    setState(() => _dragOffset = 0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SettingsStore.instance,
      builder: (context, _) => _buildWithSettings(context),
    );
  }

  Widget _buildWithSettings(BuildContext context) {
    final message = widget.message;
    final screenWidth = MediaQuery.of(context).size.width;
    final msgText = message.message ?? '';
    final attachments = message.attachments;
    final hasAttachments = attachments.isNotEmpty;
    final senderName = message.sender.name ?? 'User ${message.sender.uid}';
    final timeStr = _formatTime(message.createdAt);

    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;

    final bubbleColor = _isMe
        ? CupertinoColors.activeBlue
        : (isDark
              ? CupertinoColors.systemGrey5.darkColor
              : const Color(0xfff0f0f0));
    final textColor = _isMe
        ? CupertinoColors.white
        : CupertinoColors.label.resolveFrom(context);
    final metaColor = _isMe
        ? CupertinoColors.white.withAlpha(180)
        : CupertinoColors.secondaryLabel.resolveFrom(context);

    final initial = (senderName.isNotEmpty ? senderName[0] : '?').toUpperCase();
    final maxBubbleWidth = screenWidth * 0.75;

    final editedLabel = message.isEdited ? 'edited ' : '';
    Widget timeWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message.isEdited)
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Text(
              'edited',
              style: TextStyle(color: metaColor, fontSize: 11),
            ),
          ),
        Text(timeStr, style: TextStyle(color: metaColor, fontSize: 11)),
      ],
    );

    final timePainter = TextPainter(
      text: TextSpan(
        text: ' $editedLabel$timeStr',
        style: const TextStyle(fontSize: 11),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: double.infinity);
    final timeSpacerWidth = timePainter.width + 8;

    final linkColor = _isMe
        ? CupertinoColors.white
        : CupertinoColors.activeBlue;
    final fontScale = SettingsStore.instance.chatFontScale;
    final messageFontSize = 15 * fontScale;
    final replyFontSize = 13 * fontScale;

    Widget bubbleContent;
    if (msgText.isNotEmpty) {
      bubbleContent = Stack(
        children: [
          Text.rich(
            TextSpan(
              children: [
                ..._buildLinkedSpans(
                  msgText,
                  TextStyle(color: textColor, fontSize: messageFontSize),
                  linkColor,
                ),
                WidgetSpan(
                  child: SizedBox(width: timeSpacerWidth, height: 14),
                ),
              ],
            ),
          ),
          Positioned(right: 0, bottom: 0, child: timeWidget),
        ],
      );
    } else {
      bubbleContent = Align(
        alignment: Alignment.centerRight,
        child: timeWidget,
      );
    }

    Widget fullContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!_isMe && widget.showSenderName)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              senderName,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: textColor,
              ),
            ),
          ),
        if (message.replyToMessage != null)
          GestureDetector(
            onTap: widget.onTapReply,
            child: _buildReplyQuote(
              context,
              message.replyToMessage!,
              replyFontSize,
            ),
          ),
        if (hasAttachments)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _buildAttachments(context, attachments, maxBubbleWidth),
          ),
        bubbleContent,
      ],
    );

    Widget bubble = Container(
      constraints: BoxConstraints(maxWidth: maxBubbleWidth),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(_isMe ? 18 : 4),
          bottomRight: Radius.circular(_isMe ? 4 : 18),
        ),
      ),
      child: fullContent,
    );

    Widget avatar = Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: isDark
            ? CupertinoColors.systemGrey4.darkColor
            : CupertinoColors.systemGrey4.color,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: CupertinoColors.white,
        ),
      ),
    );

    final replyIconOpacity = (_dragOffset.abs() / _replyThreshold).clamp(
      0.0,
      1.0,
    );

    Widget messageRow = AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      decoration: BoxDecoration(
        color: widget.isHighlighted
            ? CupertinoColors.systemYellow.withAlpha(60)
            : const Color(0x00000000),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          mainAxisAlignment: _isMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: _isMe
              ? [
                  bubble,
                  if (widget.showAvatar) ...[
                    const SizedBox(width: 6),
                    avatar,
                  ] else
                    const SizedBox(width: 36),
                ]
              : [
                  if (widget.showAvatar) ...[
                    avatar,
                    const SizedBox(width: 6),
                  ] else
                    const SizedBox(width: 36),
                  bubble,
                ],
        ),
      ),
    );

    return GestureDetector(
      onLongPress: widget.onLongPress,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          Positioned(
            right: 12,
            child: Opacity(
              opacity: replyIconOpacity,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey5.resolveFrom(context),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.reply,
                  size: 22,
                  color: CupertinoColors.activeBlue,
                ),
              ),
            ),
          ),
          AnimatedContainer(
            duration: _dragOffset == 0
                ? const Duration(milliseconds: 200)
                : Duration.zero,
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(_dragOffset, 0, 0),
            child: messageRow,
          ),
        ],
      ),
    );
  }

  Widget _buildReplyQuote(
    BuildContext context,
    ReplyToMessage reply,
    double replyFontSize,
  ) {
    final replySender = reply.sender.name ?? 'User ${reply.sender.uid}';
    final replyText = reply.isDeleted
        ? 'Message deleted'
        : (reply.message ?? '');

    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;

    final quoteBackgroundColor = _isMe
        ? Color.lerp(CupertinoColors.activeBlue, const Color(0xFF000000), 0.15)!
        : (isDark
              ? CupertinoColors.systemGrey4.darkColor
              : CupertinoColors.systemGrey5.color);
    final quoteBorderColor = _isMe
        ? CupertinoColors.white.withAlpha(150)
        : CupertinoColors.activeBlue;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: quoteBackgroundColor,
        border: Border(left: BorderSide(color: quoteBorderColor, width: 3)),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(4),
          bottomRight: Radius.circular(4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            replySender,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: quoteBorderColor,
            ),
          ),
          Text(
            replyText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: replyFontSize,
              color: _isMe
                  ? CupertinoColors.white.withAlpha(200)
                  : CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachments(
    BuildContext context,
    List<Attachment> attachments,
    double maxBubbleWidth,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final attachment in attachments)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _buildAttachmentItem(
              context,
              attachment,
              maxBubbleWidth,
            ),
          ),
      ],
    );
  }

  Widget _buildAttachmentItem(
    BuildContext context,
    Attachment attachment,
    double maxBubbleWidth,
  ) {
    final borderRadius = BorderRadius.circular(10);
    if (attachment.isImage && attachment.url.isNotEmpty) {
      final maxHeight = maxBubbleWidth * 0.75;
      return GestureDetector(
        onTap: () => _openUrl(attachment.url),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxBubbleWidth,
              maxHeight: maxHeight,
            ),
            child: Image.network(
              attachment.url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: maxBubbleWidth,
                height: 120,
                color: CupertinoColors.systemGrey5.resolveFrom(context),
                alignment: Alignment.center,
                child: const Icon(CupertinoIcons.photo),
              ),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _openUrl(attachment.url),
      child: Container(
        constraints: BoxConstraints(maxWidth: maxBubbleWidth),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey5.resolveFrom(context),
          borderRadius: borderRadius,
          border: Border.all(
            color: CupertinoColors.systemGrey4.resolveFrom(context),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.doc,
              size: 20,
              color: CupertinoColors.activeBlue.resolveFrom(context),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                attachment.fileName.isNotEmpty
                    ? attachment.fileName
                    : 'Attachment',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.label.resolveFrom(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openUrl(String url) {
    if (url.isEmpty) return;
    launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  }

  // ---- Link-detection helper ----
  static final RegExp _urlRegex = RegExp(
    r'(https?://[^\s<>]+|www\.[^\s<>]+)',
    caseSensitive: false,
  );

  /// Build a list of inline spans for the given text, with URLs converted to tappable links.
  List<InlineSpan> _buildLinkedSpans(
    String text,
    TextStyle baseStyle,
    Color linkColor,
  ) {
    final spans = <InlineSpan>[];
    int lastEnd = 0;
    for (final match in _urlRegex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, match.start),
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
            color: linkColor,
            decoration: TextDecoration.underline,
            decorationColor: linkColor,
          ),
          recognizer: recognizer,
        ),
      );
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: baseStyle));
    }
    if (spans.isEmpty) {
      spans.add(TextSpan(text: text, style: baseStyle));
    }
    return spans;
  }

  String _formatTime(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}
