import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../domain/conversation_message.dart';
import '../../../../../app/theme/style_config.dart';
import '../../../models/message_models.dart';
import '../../../models/message_preview_formatter.dart';
import '../message_attachment_previews.dart';
import '../video_popup_player.dart';
import 'linkified_message_text.dart';
import 'message_bubble_meta.dart';
import 'message_bubble_presentation.dart';
import 'message_reactions.dart';
import 'message_thread_indicator.dart';
import 'voice_message_bubble.dart';

class MessageBubbleContent extends StatelessWidget {
  const MessageBubbleContent({
    super.key,
    required this.message,
    required this.presentation,
    required this.chatMessageFontSize,
    required this.isMe,
    required this.showSenderName,
    this.onTapReply,
    this.onOpenThread,
    this.onOpenAttachment,
    this.onToggleReaction,
  });

  final ConversationMessage message;
  final MessageBubblePresentation presentation;
  final double chatMessageFontSize;
  final bool isMe;
  final bool showSenderName;
  final VoidCallback? onTapReply;
  final VoidCallback? onOpenThread;
  final ValueChanged<AttachmentItem>? onOpenAttachment;
  final ValueChanged<String>? onToggleReaction;

  static const FontWeight _bubbleFontWeight = FontWeight.w400;
  static const double _emptyBubbleMinWidth = 48;

  TextStyle _bubbleStyle(
    BuildContext context, {
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

  @override
  Widget build(BuildContext context) {
    final hasAttachments = message.attachments.isNotEmpty;
    final contentChildren = <Widget>[
      if (!isMe && showSenderName) _buildSenderHeader(context),
      if (message.replyToMessage != null)
        GestureDetector(
          onTap: onTapReply,
          child: _buildReplyQuote(context, message.replyToMessage!),
        ),
    ];

    // deleted message
    if (message.isDeleted) {
      contentChildren.add(
        Text(
          '[Deleted]',
          style: _bubbleStyle(
            context,
            color: presentation.metaColor,
            fontSize: chatMessageFontSize,
            fontStyle: FontStyle.italic,
            fontWeight: _bubbleFontWeight,
          ),
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: contentChildren,
      );
    }

    if (hasAttachments) {
      if (contentChildren.isNotEmpty) {
        contentChildren.add(const SizedBox(height: 8));
      }
      contentChildren.add(
        _buildAttachmentSection(context, message.attachments),
      );
    }

    if (hasAttachments || message.messageType != 'system') {
      if (contentChildren.isNotEmpty) {
        contentChildren.add(const SizedBox(height: 4));
      }
      contentChildren.add(_buildMessageBody(context));
    }

    final threadInfo = message.threadInfo;
    if (threadInfo != null &&
        threadInfo.replyCount > 0 &&
        onOpenThread != null) {
      contentChildren.add(const SizedBox(height: 4));
      contentChildren.add(
        MessageThreadIndicator(
          threadInfo: threadInfo,
          isMe: isMe,
          presentation: presentation,
          onTap: onOpenThread,
        ),
      );
    }

    if (message.reactions.isNotEmpty) {
      contentChildren.add(const SizedBox(height: 8));
      contentChildren.add(_buildReactions(context));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: contentChildren,
    );
  }

  Widget _buildSenderHeader(BuildContext context) {
    final gender = message.sender.gender;
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
                context,
                fontWeight: FontWeight.w700,
                fontSize: AppFontSizes.body,
                color: presentation.textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
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

  Widget _buildMessageBody(BuildContext context) {
    final messageText = message.message ?? '';
    final metaWidget = _buildMetaWidget(context);

    if (messageText.trim().isEmpty) {
      return ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: _emptyBubbleMinWidth,
          minHeight: presentation.minBubbleContentHeight,
        ),
        child: Align(alignment: Alignment.bottomRight, child: metaWidget),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: double.infinity,
        child: Stack(
          children: [
            LinkifiedMessageText(
              text: messageText,
              textStyle: _bubbleStyle(
                context,
                color: presentation.textColor,
                fontSize: chatMessageFontSize,
                height: 1.28,
                fontWeight: _bubbleFontWeight,
              ),
              linkColor: presentation.linkColor,
              trailingSpacerWidth: presentation.timeSpacerWidth,
            ),
            Positioned(right: 0, bottom: 0, child: metaWidget),
          ],
        ),
      ),
    );
  }

  // Meta widget contains is message edited label and time label
  Widget _buildMetaWidget(BuildContext context) {
    return MessageBubbleMeta(
      message: message,
      presentation: presentation,
      isMe: isMe,
      fontWeight: _bubbleFontWeight,
    );
  }

  Widget _buildAttachmentSection(
    BuildContext context,
    List<AttachmentItem> attachments,
  ) {
    final maxAttachmentWidth = presentation.maxBubbleWidth - 24;

    return Align(
      alignment: Alignment.centerRight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < attachments.length; index++) ...[
            if (index > 0) const SizedBox(height: 8),
            _buildAttachmentPreview(
              context,
              attachments[index],
              maxAttachmentWidth: maxAttachmentWidth,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAttachmentPreview(
    BuildContext context,
    AttachmentItem attachment, {
    required double maxAttachmentWidth,
  }) {
    if (attachment.isAudio && message.messageType == 'audio') {
      return VoiceMessageBubble(
        attachment: attachment,
        isMe: isMe,
        message: message,
        presentation: presentation,
      );
    }
    if (attachment.isVideo && attachment.url.isNotEmpty) {
      return VideoAttachmentPreview(
        attachment: attachment,
        onTap: () => onOpenAttachment?.call(attachment),
      );
    }
    if (attachment.isImage && attachment.url.isNotEmpty) {
      return MessageImageAttachmentPreview(
        attachment: attachment,
        onTap: () => onOpenAttachment?.call(attachment),
        fallback: _buildFileAttachmentTile(context, attachment),
        maxWidth: maxAttachmentWidth,
      );
    }
    return GestureDetector(
      onTap: () => onOpenAttachment?.call(attachment),
      child: _buildFileAttachmentTile(context, attachment),
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
        color: isMe
            ? context.appColors.chatAttachmentChipSent
            : context.appColors.chatAttachmentChipReceived,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            attachment.isAudio
                ? CupertinoIcons.mic_fill
                : attachment.isVideo
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
                context,
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
    final quoteBackgroundColor = isMe
        ? CupertinoColors.white.withAlpha(26)
        : CupertinoColors.black.withAlpha(15);
    final quoteBorderColor = isMe
        ? CupertinoColors.white.withAlpha(128)
        : CupertinoColors.activeBlue.resolveFrom(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: quoteBackgroundColor,
        border: Border(left: BorderSide(color: quoteBorderColor, width: 3)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            replySender,
            style: _bubbleStyle(
              context,
              fontWeight: FontWeight.w600,
              fontSize: 11,
              color: presentation.textColor.withAlpha(217),
            ),
          ),
          Text(
            formatReplyPreview(reply),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _bubbleStyle(
              context,
              fontSize: 12,
              fontWeight: _bubbleFontWeight,
              color: presentation.textColor.withAlpha(179),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReactions(BuildContext context) {
    final isInteractive =
        onToggleReaction != null &&
        message.messageType != 'sticker' &&
        !message.isDeleted;
    return MessageReactions(
      reactions: message.reactions,
      maxBubbleWidth: presentation.maxBubbleWidth,
      isMe: isMe,
      isInteractive: isInteractive,
      onToggleReaction: onToggleReaction,
    );
  }
}
