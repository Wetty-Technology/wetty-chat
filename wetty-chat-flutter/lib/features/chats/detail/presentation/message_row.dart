import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/style_config.dart';
import '../../../../core/network/api_config.dart';
import '../../models/message_models.dart';
import 'attachment_viewer_page.dart';
import 'message_attachment_previews.dart';
import 'message_avatar.dart';
import 'video_popup_player.dart';

class MessageRow extends StatefulWidget {
  const MessageRow({
    super.key,
    required this.message,
    required this.chatMessageFontSize,
    this.isHighlighted = false,
    this.onLongPress,
    this.onReply,
    this.onTapReply,
    this.onOpenThread,
    this.showSenderName = true,
    this.showAvatar = true,
  });

  final MessageItem message;
  final double chatMessageFontSize;
  final bool isHighlighted;
  final VoidCallback? onLongPress;
  final VoidCallback? onReply;
  final VoidCallback? onTapReply;
  final VoidCallback? onOpenThread;
  final bool showSenderName;
  final bool showAvatar;

  @override
  State<MessageRow> createState() => _MessageRowState();
}

class _MessageRowState extends State<MessageRow>
    with SingleTickerProviderStateMixin {
  static const double _replyThreshold = 60;
  static const FontWeight _bubbleFontWeight = FontWeight.w400;

  double _dragOffset = 0;
  bool _hasTriggeredReply = false;

  bool get _isMe {
    final currentUserId = ApiSession.currentUserId;
    return currentUserId != null && widget.message.sender.uid == currentUserId;
  }

  TextStyle _bubbleStyle({
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
    FontStyle? fontStyle,
  }) {
    return appBubbleTextStyle(
      context,
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      fontStyle: fontStyle,
    );
  }

  bool get _isDesktopPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
        return true;
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
        return false;
    }
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

  Future<void> _openAttachment(AttachmentItem attachment) async {
    if (attachment.url.isEmpty) {
      return;
    }

    if (attachment.isImage) {
      if (!mounted) return;
      await Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => AttachmentViewerPage(attachment: attachment),
        ),
      );
      return;
    }

    if (attachment.isVideo) {
      if (!mounted) return;
      await showVideoPlayerPopup(context, attachment);
      return;
    }

    await launchUrl(
      Uri.parse(attachment.url),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final colors = context.appColors;
    final presentation = _MessageRowPresentation.fromContext(
      context: context,
      message: message,
      isMe: _isMe,
      chatMessageFontSize: widget.chatMessageFontSize,
    );
    final replyIconOpacity = (_dragOffset.abs() / _replyThreshold).clamp(
      0.0,
      1.0,
    );
    return GestureDetector(
      onLongPress: _isDesktopPlatform ? null : widget.onLongPress,
      onSecondaryTapUp: _isDesktopPlatform
          ? (_) => widget.onLongPress?.call()
          : null,
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
                  color: colors.chatReplyActionBackground,
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
            child: _buildMessageRow(context, presentation),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageRow(
    BuildContext context,
    _MessageRowPresentation presentation,
  ) {
    final bubble = _buildBubble(context, presentation);
    final avatar = _buildAvatar(context, presentation.senderName);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      decoration: BoxDecoration(
        color: widget.isHighlighted
            ? CupertinoColors.systemYellow.withAlpha(60)
            : const Color(0x00000000),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Align(
          alignment: _isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
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
      ),
    );
  }

  Widget _buildBubble(
    BuildContext context,
    _MessageRowPresentation presentation,
  ) {
    const bubbleRadius = Radius.circular(16);
    const tailRadius = Radius.circular(4);
    final borderRadius = BorderRadius.only(
      topLeft: bubbleRadius,
      topRight: bubbleRadius,
      bottomLeft: !_isMe ? tailRadius : bubbleRadius,
      bottomRight: _isMe ? tailRadius : bubbleRadius,
    );

    return IntrinsicWidth(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: presentation.maxBubbleWidth),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
          decoration: BoxDecoration(
            color: presentation.bubbleColor,
            borderRadius: borderRadius,
          ),
          child: DefaultTextStyle(
            style: _bubbleStyle(
              color: presentation.textColor,
              fontSize: widget.chatMessageFontSize,
              height: 1.28,
              fontWeight: _bubbleFontWeight,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: _buildBubbleContent(context, presentation),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBubbleContent(
    BuildContext context,
    _MessageRowPresentation presentation,
  ) {
    final message = widget.message;
    final contentChildren = <Widget>[
      if (!_isMe && widget.showSenderName) _buildSenderHeader(presentation),
      if (message.replyToMessage != null)
        GestureDetector(
          onTap: widget.onTapReply,
          child: _buildReplyQuote(context, message.replyToMessage!),
        ),
    ];

    // deleted message
    if (message.isDeleted) {
      contentChildren.add(
        Text(
          '[Deleted]',
          style: _bubbleStyle(
            color: presentation.metaColor,
            fontSize: widget.chatMessageFontSize,
            fontStyle: FontStyle.italic,
            fontWeight: _bubbleFontWeight,
          ),
        ),
      );
      return contentChildren;
    }

    contentChildren.add(_buildMessageBody(context, presentation));

    if (message.attachments.isNotEmpty) {
      if (contentChildren.isNotEmpty) {
        contentChildren.add(const SizedBox(height: 8));
      }
      contentChildren.add(
        _buildAttachmentSection(context, message.attachments),
      );
    }

    final threadInfo = message.threadInfo;
    if (threadInfo != null &&
        threadInfo.replyCount > 0 &&
        widget.onOpenThread != null) {
      contentChildren.add(const SizedBox(height: 8));
      contentChildren.add(_buildThreadInfo(context, threadInfo));
    }

    return contentChildren;
  }

  Widget _buildSenderHeader(_MessageRowPresentation presentation) {
    final gender = widget.message.sender.gender;
    const String maleBadgeSvg =
        '<svg viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg"><path d="M896.35739 415.483806V127.690194h-287.794636l107.116623 107.116623-108.319007 108.316961c-49.568952-34.997072-110.052488-55.56348-175.344541-55.56348-168.101579 0-304.374242 136.273686-304.374242 304.374242s136.273686 304.374242 304.374242 304.374243S736.390072 760.03612 736.390072 591.93454c0-61.631686-18.3356-118.972649-49.824779-166.901241L796.238135 315.365574l100.119255 100.118232zM432.015829 800.190655c-115.015523 0-208.256114-93.240591-208.256115-208.256115s93.240591-208.256114 208.256115-208.256114 208.256114 93.240591 208.256114 208.256114-93.240591 208.256114-208.256114 208.256115z" fill="#CCCCCC"/></svg>';
    const String femaleBadgeSvg =
        '<svg viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg"><path d="M815.562249 368.20706c0-167.652348-135.909389-303.56276-303.562761-303.562761S208.436728 200.554712 208.436728 368.20706c0 151.34187 110.7555 276.800233 255.632121 299.782667v67.687612H304.299029v95.862301h159.76982v127.816061h95.862302V831.53964h159.76982v-95.862301H559.930127v-67.687612c144.875598-22.982434 255.632121-148.440797 255.632122-299.782667z m-511.26322 0c0-114.708532 92.991927-207.700459 207.700459-207.700459s207.700459 92.991927 207.700459 207.700459-92.991927 207.700459-207.700459 207.700459-207.700459-92.991927-207.700459-207.700459z" fill="#CCCCCC"/></svg>';

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              presentation.senderName,
              style: _bubbleStyle(
                fontWeight: FontWeight.w700,
                fontSize: AppFontSizes.body,
                color: presentation.textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // gender badge
          if (gender == 1 || gender == 2) ...[
            const SizedBox(width: 4),
            Opacity(
              opacity: 0.9,
              child: SvgPicture.string(
                gender == 1 ? maleBadgeSvg : femaleBadgeSvg,
                width: 11,
                height: 11,
                colorFilter: ColorFilter.mode(
                  gender == 1
                      ? const Color(0xFF4A90E2)
                      : const Color(0xFFE86DA8),
                  BlendMode.srcIn,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageBody(
    BuildContext context,
    _MessageRowPresentation presentation,
  ) {
    final messageText = widget.message.message ?? '';
    final metaWidget = _buildMetaWidget(presentation);

    if (messageText.isEmpty) {
      return Stack(
        children: [
          SizedBox(
            width: presentation.timeSpacerWidth,
            height: presentation.minBubbleContentHeight,
          ),
          Positioned(right: 0, bottom: 0, child: metaWidget),
        ],
      );
    }

    return Stack(
      children: [
        Text.rich(
          TextSpan(
            children: [
              ..._buildLinkedSpans(
                messageText,
                _bubbleStyle(
                  color: presentation.textColor,
                  fontSize: widget.chatMessageFontSize,
                  height: 1.28,
                  fontWeight: _bubbleFontWeight,
                ),
                presentation.linkColor,
              ),
              WidgetSpan(
                child: SizedBox(
                  width: presentation.timeSpacerWidth,
                  height: 14,
                ),
              ),
            ],
          ),
        ),
        Positioned(right: 0, bottom: 0, child: metaWidget),
      ],
    );
  }

  // Meta widget contains is message edited label and time label
  Widget _buildMetaWidget(_MessageRowPresentation presentation) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // show edited label
        if (widget.message.isEdited)
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Text(
              'edited',
              style: _bubbleStyle(
                color: presentation.metaColor,
                fontSize: AppFontSizes.bubbleMeta,
                fontWeight: _bubbleFontWeight,
              ),
            ),
          ),
        // show time label
        Text(
          presentation.timeStr,
          style: _bubbleStyle(
            color: presentation.metaColor,
            fontSize: AppFontSizes.bubbleMeta,
            fontWeight: _bubbleFontWeight,
          ),
        ),
      ],
    );
  }

  // TODO: this method is not tested
  Widget _buildThreadInfo(BuildContext context, ThreadInfo threadInfo) {
    return GestureDetector(
      onTap: widget.onOpenThread,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _isMe ? const Color(0xFFF2E9DE) : const Color(0xFFF1EAE3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.chat_bubble_2,
              size: 15,
              color: const Color(0xFF8B6D52),
            ),
            const SizedBox(width: 6),
            Text(
              '${threadInfo.replyCount} repl${threadInfo.replyCount == 1 ? 'y' : 'ies'}',
              style: appBubbleTextStyle(
                context,
                fontSize: AppFontSizes.meta,
                fontWeight: _bubbleFontWeight,
                color: const Color(0xFF8B6D52),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, String senderName) {
    final avatarUrl = widget.message.sender.avatarUrl;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return MessageAvatar(
        avatarUrl: avatarUrl,
        fallbackBuilder: () => _buildFallbackAvatar(context, senderName),
      );
    }
    final initial = (senderName.isNotEmpty ? senderName[0] : '?').toUpperCase();
    return _buildFallbackAvatar(context, initial);
  }

  // Build fallback avatar from user's initial
  Widget _buildFallbackAvatar(BuildContext context, String initial) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: context.appColors.avatarBackground,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: appOnDarkTextStyle(
          context,
          fontSize: AppFontSizes.bodySmall,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildAttachmentSection(
    BuildContext context,
    List<AttachmentItem> attachments,
  ) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: attachments.map((attachment) {
        if (attachment.isVideo) {
          return VideoAttachmentPreview(
            attachment: attachment,
            onTap: () => _openAttachment(attachment),
          );
        }
        if (attachment.isImage) {
          return MessageImageAttachmentPreview(
            attachment: attachment,
            onTap: () => _openAttachment(attachment),
            fallback: _buildFileAttachmentTile(context, attachment),
          );
        }
        return GestureDetector(
          onTap: () => _openAttachment(attachment),
          child: _buildFileAttachmentTile(context, attachment),
        );
      }).toList(),
    );
  }

  Widget _buildFileAttachmentTile(
    BuildContext context,
    AttachmentItem attachment,
  ) {
    return Container(
      width: 180,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _isMe
            ? context.appColors.chatAttachmentChipSent
            : context.appColors.chatAttachmentChipReceived,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            attachment.isVideo
                ? CupertinoIcons.play_rectangle
                : CupertinoIcons.doc,
            size: 18,
            color: const Color(0xFF8B6D52),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              attachment.fileName.isEmpty ? 'Attachment' : attachment.fileName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: _bubbleStyle(
                fontSize: AppFontSizes.bodySmall,
                fontWeight: _bubbleFontWeight,
                color: context.appColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyQuote(BuildContext context, ReplyToMessage reply) {
    final replySender = reply.sender.name ?? 'User ${reply.sender.uid}';
    final replyText = reply.isDeleted
        ? 'Message deleted'
        : (reply.message ?? '');

    final quoteBackgroundColor = _isMe
        ? context.appColors.chatAttachmentChipSent
        : context.appColors.chatAttachmentChipReceived;
    final quoteBorderColor = const Color(0xFFB98F63);

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
            style: _bubbleStyle(
              fontWeight: _bubbleFontWeight,
              fontSize: AppFontSizes.meta,
              color: quoteBorderColor,
            ),
          ),
          Text(
            replyText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _bubbleStyle(
              fontSize: AppFontSizes.replyQuote,
              fontWeight: _bubbleFontWeight,
              color: context.appColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  static final RegExp _urlRegex = RegExp(
    r'(https?://[^\s<>]+|www\.[^\s<>]+)',
    caseSensitive: false,
  );

  List<InlineSpan> _buildLinkedSpans(
    String text,
    TextStyle baseStyle,
    Color linkColor,
  ) {
    final spans = <InlineSpan>[];
    var lastEnd = 0;
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
}

class _MessageRowPresentation {
  const _MessageRowPresentation({
    required this.senderName,
    required this.timeStr,
    required this.maxBubbleWidth,
    required this.bubbleColor,
    required this.textColor,
    required this.metaColor,
    required this.linkColor,
    required this.timeSpacerWidth,
    required this.minBubbleContentHeight,
  });

  factory _MessageRowPresentation.fromContext({
    required BuildContext context,
    required MessageItem message,
    required bool isMe,
    required double chatMessageFontSize,
  }) {
    final colors = context.appColors;
    final senderName = message.sender.name ?? 'User ${message.sender.uid}';
    final timeStr = _formatTime(message.createdAt);
    final screenWidth = MediaQuery.sizeOf(context).width;

    return _MessageRowPresentation(
      senderName: senderName,
      timeStr: timeStr,
      maxBubbleWidth: screenWidth * 0.82,
      bubbleColor: isMe ? colors.chatSentBubble : colors.chatReceivedBubble,
      textColor: isMe ? colors.textOnAccent : colors.textPrimary,
      metaColor: isMe ? colors.chatSentMeta : colors.chatReceivedMeta,
      linkColor: isMe ? colors.chatLinkOnSent : colors.chatLinkOnReceived,
      timeSpacerWidth: _measureMetaWidth(context, message, timeStr) + 8,
      minBubbleContentHeight: chatMessageFontSize * 1.28,
    );
  }

  final String senderName;
  final String timeStr;
  final double maxBubbleWidth;
  final Color bubbleColor;
  final Color textColor;
  final Color metaColor;
  final Color linkColor;
  final double timeSpacerWidth;
  final double minBubbleContentHeight;

  // Measure the width of the metadata text so the message body
  // reserves space for the timestamp row in the bottom-right corner.
  static double _measureMetaWidth(
    BuildContext context,
    MessageItem message,
    String timeStr,
  ) {
    final metaPainter = TextPainter(
      text: TextSpan(
        text: '${message.isEdited ? ' edited' : ''} $timeStr',
        style: appBubbleMetaTextStyle(
          context,
          fontSize: AppFontSizes.bubbleMeta,
        ),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: double.infinity);

    return metaPainter.width;
  }

  static String _formatTime(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}
