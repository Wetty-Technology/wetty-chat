import 'dart:async';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/style_config.dart';
import '../../../../core/network/api_config.dart';
import '../../models/message_models.dart';
import '../data/media_preview_cache.dart';
import 'attachment_viewer_page.dart';
import 'video_popup_player.dart';

class MessageRow extends StatefulWidget {
  const MessageRow({
    super.key,
    required this.message,
    required this.chatFontScale,
    this.isHighlighted = false,
    this.onLongPress,
    this.onReply,
    this.onTapReply,
    this.onOpenThread,
    this.showSenderName = true,
    this.showAvatar = true,
  });

  final MessageItem message;
  final double chatFontScale;
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
  static const String _maleBadgeSvg =
      '<svg viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg"><path d="M896.35739 415.483806V127.690194h-287.794636l107.116623 107.116623-108.319007 108.316961c-49.568952-34.997072-110.052488-55.56348-175.344541-55.56348-168.101579 0-304.374242 136.273686-304.374242 304.374242s136.273686 304.374242 304.374242 304.374243S736.390072 760.03612 736.390072 591.93454c0-61.631686-18.3356-118.972649-49.824779-166.901241L796.238135 315.365574l100.119255 100.118232zM432.015829 800.190655c-115.015523 0-208.256114-93.240591-208.256115-208.256115s93.240591-208.256114 208.256115-208.256114 208.256114 93.240591 208.256114 208.256114-93.240591 208.256114-208.256114 208.256115z" fill="#CCCCCC"/></svg>';
  static const String _femaleBadgeSvg =
      '<svg viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg"><path d="M815.562249 368.20706c0-167.652348-135.909389-303.56276-303.562761-303.562761S208.436728 200.554712 208.436728 368.20706c0 151.34187 110.7555 276.800233 255.632121 299.782667v67.687612H304.299029v95.862301h159.76982v127.816061h95.862302V831.53964h159.76982v-95.862301H559.930127v-67.687612c144.875598-22.982434 255.632121-148.440797 255.632122-299.782667z m-511.26322 0c0-114.708532 92.991927-207.700459 207.700459-207.700459s207.700459 92.991927 207.700459 207.700459-92.991927 207.700459-207.700459 207.700459-207.700459-92.991927-207.700459-207.700459z" fill="#CCCCCC"/></svg>';

  double _dragOffset = 0;
  bool _hasTriggeredReply = false;

  bool get _isMe {
    final currentUserId = ApiSession.currentUserId;
    return currentUserId != null && widget.message.sender.uid == currentUserId;
  }

  double _scaled(double size) => size * widget.chatFontScale;

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
    final senderName = message.sender.name ?? 'User ${message.sender.uid}';
    final timeStr = _formatTime(message.createdAt);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxBubbleWidth = screenWidth * 0.82;
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;

    final bubbleColor = _isMe
        ? (isDark ? const Color(0xFF3C444D) : const Color(0xFFF7F5F2))
        : (isDark ? const Color(0xFF30343A) : const Color(0xFFF8F6F3));
    final bubbleBorderColor = _isMe
        ? (isDark ? const Color(0xFF515C67) : const Color(0xFFE9E1D7))
        : (isDark ? const Color(0xFF454A52) : const Color(0xFFEEE7DE));
    final textColor = CupertinoColors.label.resolveFrom(context);
    final metaColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    final linkColor = const Color(0xFF3C82F6);

    final initial = (senderName.isNotEmpty ? senderName[0] : '?').toUpperCase();
    final timeWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message.isEdited)
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Text(
              'edited',
              style: _bubbleStyle(
                color: metaColor,
                fontSize: AppFontSizes.bubbleMeta,
                fontWeight: _bubbleFontWeight,
              ),
            ),
          ),
        Text(
          timeStr,
          style: _bubbleStyle(
            color: metaColor,
            fontSize: AppFontSizes.bubbleMeta,
            fontWeight: _bubbleFontWeight,
          ),
        ),
      ],
    );
    final timePainter = TextPainter(
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
    final timeSpacerWidth = timePainter.width + 8;
    final minBubbleContentHeight = _scaled(AppFontSizes.bubbleText) * 1.28;

    final contentChildren = <Widget>[
      if (!_isMe && widget.showSenderName)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  senderName,
                  style: _bubbleStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: _scaled(AppFontSizes.body),
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (message.sender.gender == 1 || message.sender.gender == 2) ...[
                const SizedBox(width: 4),
                Opacity(
                  opacity: 0.9,
                  child: SvgPicture.string(
                    message.sender.gender == 1
                        ? _maleBadgeSvg
                        : _femaleBadgeSvg,
                    width: 11,
                    height: 11,
                    colorFilter: ColorFilter.mode(
                      message.sender.gender == 1
                          ? const Color(0xFF4A90E2)
                          : const Color(0xFFE86DA8),
                      BlendMode.srcIn,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      if (message.replyToMessage != null)
        GestureDetector(
          onTap: widget.onTapReply,
          child: _buildReplyQuote(context, message.replyToMessage!),
        ),
    ];

    if (message.isDeleted) {
      contentChildren.add(
        Text(
          '[Deleted]',
          style: _bubbleStyle(
            color: metaColor,
            fontSize: _scaled(AppFontSizes.bubbleText),
            fontStyle: FontStyle.italic,
            fontWeight: _bubbleFontWeight,
          ),
        ),
      );
    } else {
      final msgText = message.message ?? '';
      if (msgText.isNotEmpty) {
        contentChildren.add(
          Stack(
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    ..._buildLinkedSpans(
                      msgText,
                      _bubbleStyle(
                        color: textColor,
                        fontSize: _scaled(AppFontSizes.bubbleText),
                        height: 1.28,
                        fontWeight: _bubbleFontWeight,
                      ),
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
          ),
        );
      } else {
        contentChildren.add(
          Stack(
            children: [
              SizedBox(width: timeSpacerWidth, height: minBubbleContentHeight),
              Positioned(right: 0, bottom: 0, child: timeWidget),
            ],
          ),
        );
      }

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
        contentChildren.add(
          GestureDetector(
            onTap: widget.onOpenThread,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _isMe
                    ? const Color(0xFFF2E9DE)
                    : const Color(0xFFF1EAE3),
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
          ),
        );
      }
    }

    final bubble = IntrinsicWidth(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxBubbleWidth),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 9),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: bubbleBorderColor),
          ),
          child: DefaultTextStyle(
            style: _bubbleStyle(
              color: textColor,
              fontSize: _scaled(AppFontSizes.bubbleText),
              height: 1.28,
              fontWeight: _bubbleFontWeight,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: contentChildren,
            ),
          ),
        ),
      ),
    );

    final avatar = _buildAvatar(context, initial);
    final replyIconOpacity = (_dragOffset.abs() / _replyThreshold).clamp(
      0.0,
      1.0,
    );

    final messageRow = AnimatedContainer(
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

  Widget _buildAvatar(BuildContext context, String initial) {
    final avatarUrl = widget.message.sender.avatarUrl;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return _CachedAvatar(
        avatarUrl: avatarUrl,
        initial: initial,
        fallbackBuilder: () => _buildInitialAvatar(context, initial),
      );
    }
    return _buildInitialAvatar(context, initial);
  }

  Widget _buildInitialAvatar(BuildContext context, String initial) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey4.resolveFrom(context),
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
          return _CachedImageAttachmentPreview(
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
        color: _isMe ? const Color(0xFFF2E9DE) : const Color(0xFFF1EAE3),
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
                fontSize: _scaled(AppFontSizes.bodySmall),
                fontWeight: _bubbleFontWeight,
                color: CupertinoColors.label.resolveFrom(context),
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
        ? const Color(0xFFF2E9DE)
        : const Color(0xFFF1EAE3);
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
              fontSize: _scaled(AppFontSizes.replyQuote),
              fontWeight: _bubbleFontWeight,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
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

class _CachedImageAttachmentPreview extends StatefulWidget {
  const _CachedImageAttachmentPreview({
    required this.attachment,
    required this.onTap,
    required this.fallback,
  });

  final AttachmentItem attachment;
  final VoidCallback onTap;
  final Widget fallback;

  @override
  State<_CachedImageAttachmentPreview> createState() =>
      _CachedImageAttachmentPreviewState();
}

class _CachedImageAttachmentPreviewState
    extends State<_CachedImageAttachmentPreview> {
  static const int _maxDecodeRetries = 1;

  late Future<File?> _thumbnailFuture;
  int _decodeRetryCount = 0;
  bool _disableCachePreview = false;

  @override
  void initState() {
    super.initState();
    _thumbnailFuture = _loadThumbnail();
  }

  Future<File?> _loadThumbnail() {
    return MediaPreviewCache.instance.loadImageThumbnail(widget.attachment.url);
  }

  void _handleDecodeError(File file) {
    if (_decodeRetryCount >= _maxDecodeRetries) {
      unawaited(
        MediaPreviewCache.instance.invalidateImageThumbnail(
          widget.attachment.url,
          markFailure: true,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _disableCachePreview = true;
      });
      return;
    }

    _decodeRetryCount += 1;
    unawaited(
      MediaPreviewCache.instance.invalidateImageThumbnail(
        widget.attachment.url,
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _thumbnailFuture = _loadThumbnail();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 160,
          height: 160,
          child: _disableCachePreview
              ? _RawAttachmentImage(
                  url: widget.attachment.url,
                  width: 160,
                  height: 160,
                  fallback: widget.fallback,
                )
              : FutureBuilder<File?>(
                  future: _thumbnailFuture,
                  builder: (context, snapshot) {
                    final file = snapshot.data;
                    if (file != null) {
                      return Image.file(
                        file,
                        width: 160,
                        height: 160,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                        errorBuilder: (_, _, _) {
                          _handleDecodeError(file);
                          return _RawAttachmentImage(
                            url: widget.attachment.url,
                            width: 160,
                            height: 160,
                            fallback: widget.fallback,
                          );
                        },
                      );
                    }
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey5.resolveFrom(
                            context,
                          ),
                        ),
                        child: const Center(
                          child: CupertinoActivityIndicator(),
                        ),
                      );
                    }
                    return _RawAttachmentImage(
                      url: widget.attachment.url,
                      width: 160,
                      height: 160,
                      fallback: widget.fallback,
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _CachedAvatar extends StatefulWidget {
  const _CachedAvatar({
    required this.avatarUrl,
    required this.initial,
    required this.fallbackBuilder,
  });

  final String avatarUrl;
  final String initial;
  final Widget Function() fallbackBuilder;

  @override
  State<_CachedAvatar> createState() => _CachedAvatarState();
}

class _CachedAvatarState extends State<_CachedAvatar> {
  static const int _maxDecodeRetries = 1;

  late Future<File?> _avatarFuture;
  int _decodeRetryCount = 0;
  bool _disableCachePreview = false;

  @override
  void initState() {
    super.initState();
    _avatarFuture = _loadAvatar();
  }

  Future<File?> _loadAvatar() {
    return MediaPreviewCache.instance.loadAvatarThumbnail(widget.avatarUrl);
  }

  void _handleDecodeError(File file) {
    if (_decodeRetryCount >= _maxDecodeRetries) {
      unawaited(
        MediaPreviewCache.instance.invalidateAvatarThumbnail(
          widget.avatarUrl,
          markFailure: true,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _disableCachePreview = true;
      });
      return;
    }

    _decodeRetryCount += 1;
    unawaited(
      MediaPreviewCache.instance.invalidateAvatarThumbnail(widget.avatarUrl),
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _avatarFuture = _loadAvatar();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_disableCachePreview) {
      return _RawAvatar(
        avatarUrl: widget.avatarUrl,
        fallbackBuilder: widget.fallbackBuilder,
      );
    }

    return FutureBuilder<File?>(
      future: _avatarFuture,
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file != null) {
          return ClipOval(
            child: Image.file(
              file,
              width: 30,
              height: 30,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) {
                _handleDecodeError(file);
                return _RawAvatar(
                  avatarUrl: widget.avatarUrl,
                  fallbackBuilder: widget.fallbackBuilder,
                );
              },
            ),
          );
        }
        return _RawAvatar(
          avatarUrl: widget.avatarUrl,
          fallbackBuilder: widget.fallbackBuilder,
        );
      },
    );
  }
}

class _RawAttachmentImage extends StatelessWidget {
  const _RawAttachmentImage({
    required this.url,
    required this.width,
    required this.height,
    required this.fallback,
  });

  final String url;
  final double width;
  final double height;
  final Widget fallback;

  @override
  Widget build(BuildContext context) {
    if (MediaPreviewCache.instance.isKnownInvalidImageUrl(url)) {
      return fallback;
    }

    return Image.network(
      url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      headers: attachmentRequestHeadersForUrl(url),
      errorBuilder: (_, _, _) {
        MediaPreviewCache.instance.markInvalidImageUrl(url);
        return fallback;
      },
    );
  }
}

class _RawAvatar extends StatelessWidget {
  const _RawAvatar({required this.avatarUrl, required this.fallbackBuilder});

  final String avatarUrl;
  final Widget Function() fallbackBuilder;

  @override
  Widget build(BuildContext context) {
    if (MediaPreviewCache.instance.isKnownInvalidImageUrl(avatarUrl)) {
      return fallbackBuilder();
    }

    return ClipOval(
      child: Image.network(
        avatarUrl,
        width: 30,
        height: 30,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        headers: attachmentRequestHeadersForUrl(avatarUrl),
        errorBuilder: (_, _, _) {
          MediaPreviewCache.instance.markInvalidImageUrl(avatarUrl);
          return fallbackBuilder();
        },
      ),
    );
  }
}
