import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../../../../app/theme/style_config.dart';
import '../../models/message_models.dart';
import '../../models/message_preview_formatter.dart';
import '../domain/conversation_message.dart';
import 'message_bubble/message_bubble_presentation.dart';

class MessageOverlayPreview extends StatelessWidget {
  const MessageOverlayPreview({
    super.key,
    required this.message,
    required this.presentation,
    required this.chatMessageFontSize,
    required this.isMe,
    required this.showSenderName,
    required this.maxHeight,
  });

  static const double _horizontalPadding = 12;
  static const double _verticalPadding = 8;
  static const double _lineHeight = 1.28;
  static const double _senderHeaderGap = 4;
  static const double _replyGap = 6;
  static const double _replyBlockHeight = 36;
  static const double _attachmentChipHeight = 32;
  static const double _attachmentGap = 6;

  final ConversationMessage message;
  final MessageBubblePresentation presentation;
  final double chatMessageFontSize;
  final bool isMe;
  final bool showSenderName;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    const bubbleRadius = Radius.circular(18);
    const tailRadius = Radius.circular(4);
    final borderRadius = BorderRadius.only(
      topLeft: bubbleRadius,
      topRight: bubbleRadius,
      bottomLeft: !isMe ? tailRadius : bubbleRadius,
      bottomRight: isMe ? tailRadius : bubbleRadius,
    );

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      padding: const EdgeInsets.fromLTRB(
        _horizontalPadding,
        _verticalPadding,
        _horizontalPadding,
        _verticalPadding,
      ),
      decoration: BoxDecoration(
        color: presentation.bubbleColor,
        borderRadius: borderRadius,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final contentHeight = constraints.maxHeight;
          var usedHeight = 0.0;
          final children = <Widget>[];

          if (!isMe && showSenderName) {
            children.add(_buildSenderHeader(context));
            usedHeight += chatMessageFontSize + _senderHeaderGap;
          }

          final reply = message.replyToMessage;
          if (reply != null && contentHeight - usedHeight > _replyBlockHeight) {
            children.add(_buildReplyPreview(context, reply));
            usedHeight += _replyBlockHeight + _replyGap;
          }

          final showAttachmentSummary =
              message.attachments.isNotEmpty &&
              (message.message?.trim().isEmpty ?? true);
          if (showAttachmentSummary &&
              contentHeight - usedHeight > _attachmentChipHeight) {
            children.add(_buildAttachmentSummary(context));
            usedHeight += _attachmentChipHeight + _attachmentGap;
          }

          final remainingHeight = math.max(0.0, contentHeight - usedHeight);
          children.add(_buildBody(context, remainingHeight));

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          );
        },
      ),
    );
  }

  Widget _buildSenderHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _senderHeaderGap),
      child: Text(
        presentation.senderName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: appBubbleTextStyle(
          context,
          fontWeight: FontWeight.w700,
          fontSize: AppFontSizes.body,
          color: presentation.textColor,
        ),
      ),
    );
  }

  Widget _buildReplyPreview(BuildContext context, ReplyToMessage reply) {
    final replySender = reply.sender.name ?? 'User ${reply.sender.uid}';
    final quoteBackgroundColor = isMe
        ? CupertinoColors.white.withAlpha(26)
        : CupertinoColors.black.withAlpha(15);
    final quoteBorderColor = isMe
        ? CupertinoColors.white.withAlpha(128)
        : CupertinoColors.activeBlue.resolveFrom(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: _replyGap),
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: appBubbleTextStyle(
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
            style: appBubbleTextStyle(
              context,
              fontSize: 12,
              color: presentation.textColor.withAlpha(179),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentSummary(BuildContext context) {
    final previewText = formatMessagePreview(
      message: message.message,
      messageType: message.messageType,
      sticker: message.sticker,
      attachments: message.attachments,
      isDeleted: message.isDeleted,
      mentions: message.mentions,
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: _attachmentGap),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isMe
            ? context.appColors.chatAttachmentChipSent
            : context.appColors.chatAttachmentChipReceived,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        previewText.isEmpty ? attachmentPreviewLabel : previewText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: appBubbleTextStyle(
          context,
          fontSize: AppFontSizes.bodySmall,
          color: context.appColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, double maxBodyHeight) {
    final lineHeightPx = chatMessageFontSize * _lineHeight;
    final maxLines = maxBodyHeight <= 0
        ? 0
        : math.max(1, (maxBodyHeight / lineHeightPx).floor());
    final fallbackText = formatMessagePreview(
      message: message.message,
      messageType: message.messageType,
      sticker: message.sticker,
      attachments: message.attachments,
      isDeleted: message.isDeleted,
      mentions: message.mentions,
    );
    final bodyText = (message.message?.trim().isNotEmpty ?? false)
        ? message.message!.trim()
        : fallbackText;

    if (maxLines <= 0 || bodyText.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      height: math.min(maxBodyHeight, lineHeightPx * maxLines),
      child: Text(
        bodyText,
        maxLines: maxLines,
        overflow: TextOverflow.fade,
        style: appBubbleTextStyle(
          context,
          color: presentation.textColor,
          fontSize: chatMessageFontSize,
          height: _lineHeight,
        ),
      ),
    );
  }
}
