import 'package:flutter/cupertino.dart';
import '../../domain/conversation_message.dart';
import '../../../../../app/theme/style_config.dart';
import '../../../models/message_models.dart';
import '../../../models/message_preview_formatter.dart';
import '../attachment_viewer_request.dart';
import '../message_attachment_previews.dart';
import '../video_popup_player.dart';
import 'linkified_message_text.dart';
import 'message_bubble_meta.dart';
import 'message_bubble_presentation.dart';
import 'message_render_spec.dart';
import 'message_reactions.dart';
import 'message_sender_header.dart';
import 'package:chahua/features/chats/shared/presentation/sticker_image_widget.dart';
import 'message_thread_indicator.dart';
import 'voice_message_bubble.dart';

class MessageBubbleContent extends StatelessWidget {
  const MessageBubbleContent({
    super.key,
    required this.message,
    required this.presentation,
    required this.chatMessageFontSize,
    required this.isMe,
    required this.renderSpec,
    required this.currentUserId,
    this.attachmentMaxWidthOverride,
    this.onTapReply,
    this.onOpenThread,
    this.onOpenAttachment,
    this.onToggleReaction,
    this.onTapMention,
  });

  final ConversationMessage message;
  final MessageBubblePresentation presentation;
  final double chatMessageFontSize;
  final bool isMe;
  final MessageRenderSpec renderSpec;
  final int? currentUserId;
  final double? attachmentMaxWidthOverride;
  final VoidCallback? onTapReply;
  final VoidCallback? onOpenThread;
  final ValueChanged<MessageAttachmentOpenRequest>? onOpenAttachment;
  final ValueChanged<String>? onToggleReaction;
  final void Function(int uid, MentionInfo? mention)? onTapMention;

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
    final contentChildren = <Widget>[];

    if (renderSpec.showSenderName) {
      contentChildren.add(_buildSenderHeader(context));
      contentChildren.add(
        const SizedBox(height: MessageBubblePresentation.senderHeaderBodyGap),
      );
    }

    if (renderSpec.showReplyQuote && message.replyToMessage != null) {
      contentChildren.add(
        GestureDetector(
          onTap: onTapReply,
          child: _buildReplyQuote(context, message.replyToMessage!),
        ),
      );
    }

    // deleted message
    if (message.isDeleted) {
      if (contentChildren.isNotEmpty) {
        contentChildren.add(const SizedBox(height: 4));
      }
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

    if (renderSpec.showAttachments && hasAttachments) {
      if (contentChildren.isNotEmpty) {
        contentChildren.add(const SizedBox(height: 8));
      }
      contentChildren.add(
        _buildAttachmentSection(context, message.attachments),
      );
    }

    if (contentChildren.isNotEmpty &&
        (renderSpec.showReplyQuote || renderSpec.showAttachments)) {
      contentChildren.add(const SizedBox(height: 4));
    }
    if (renderSpec.showBody || renderSpec.showMeta) {
      contentChildren.add(_buildMessageBody(context));
    }

    final threadInfo = message.threadInfo;
    if (threadInfo != null &&
        threadInfo.replyCount > 0 &&
        renderSpec.showThreadIndicator) {
      contentChildren.add(const SizedBox(height: 4));
      contentChildren.add(
        MessageThreadIndicator(
          threadInfo: threadInfo,
          isMe: isMe,
          presentation: presentation,
          onTap: renderSpec.isInteractive ? onOpenThread : null,
        ),
      );
    }

    if (renderSpec.showReactions && message.reactions.isNotEmpty) {
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
    return MessageSenderHeader(
      senderName: presentation.senderName,
      textColor: presentation.textColor,
      gender: message.sender.gender,
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
              mentions: message.mentions,
              currentUserId: currentUserId,
              mentionTextColor: isMe
                  ? CupertinoColors.white
                  : CupertinoColors.activeBlue.resolveFrom(context),
              mentionBackgroundColor: isMe
                  ? CupertinoColors.white.withAlpha(46)
                  : CupertinoColors.activeBlue
                        .resolveFrom(context)
                        .withAlpha(26),
              selfMentionBackgroundColor: isMe
                  ? CupertinoColors.white.withAlpha(71)
                  : CupertinoColors.activeBlue
                        .resolveFrom(context)
                        .withAlpha(51),
              trailingSpacerWidth: presentation.timeSpacerWidth,
              onTapMention: onTapMention,
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
    final maxAttachmentWidth =
        attachmentMaxWidthOverride ?? (presentation.maxBubbleWidth - 24);

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
    final viewerRequest = buildAttachmentViewerRequest(
      message: message,
      tappedAttachment: attachment,
    );

    if (attachment.isAudio && message.messageType == 'audio') {
      return VoiceMessageBubble(
        attachment: attachment,
        isMe: isMe,
        renderSpec: renderSpec,
        message: message,
        presentation: presentation,
      );
    }
    if (attachment.isVideo && attachment.url.isNotEmpty) {
      return VideoAttachmentPreview(
        attachment: attachment,
        maxWidth: maxAttachmentWidth,
        onTap: () => onOpenAttachment?.call(
          MessageAttachmentOpenRequest(
            attachment: attachment,
            viewerRequest: viewerRequest,
          ),
        ),
      );
    }
    if (attachment.isImage && attachment.url.isNotEmpty) {
      return MessageImageAttachmentPreview(
        attachment: attachment,
        onTap: () => onOpenAttachment?.call(
          MessageAttachmentOpenRequest(
            attachment: attachment,
            viewerRequest: viewerRequest,
          ),
        ),
        fallback: _buildFileAttachmentTile(context, attachment),
        maxWidth: maxAttachmentWidth,
        heroTag: viewerRequest?.items[viewerRequest.initialIndex].heroTag,
      );
    }
    return GestureDetector(
      onTap: () => onOpenAttachment?.call(
        MessageAttachmentOpenRequest(attachment: attachment),
      ),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
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
          ),
          if (reply.messageType == 'sticker' && reply.sticker?.media != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: StickerImage(
                media: reply.sticker?.media,
                emoji: reply.sticker?.emoji,
                size: 28,
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
