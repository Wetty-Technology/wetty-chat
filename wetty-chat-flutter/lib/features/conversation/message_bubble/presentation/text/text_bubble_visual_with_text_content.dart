import 'package:chahua/features/shared/model/message/message.dart';
import 'package:chahua/features/conversation/media/presentation/attachment_viewer_request.dart';
import 'package:chahua/features/conversation/shared/presentation/conversation_presentation_scope.dart';
import 'package:flutter/cupertino.dart';

import '../../domain/bubble_theme_v2.dart';
import '../parts/attachment/bubble_attachment_section.dart';
import '../parts/reply_quote.dart';
import '../parts/sender_header.dart';
import '../parts/thread_indicator.dart';
import 'text_bubble_v2.dart';
import 'text_bubble_plain_content.dart';

class TextBubbleVisualWithTextContent extends StatelessWidget {
  const TextBubbleVisualWithTextContent({
    super.key,
    required this.message,
    required this.theme,
    required this.showSenderName,
    this.onTapReply,
    this.onOpenThread,
    this.onOpenAttachment,
  });

  final ConversationMessageV2 message;
  final BubbleThemeV2 theme;
  final bool showSenderName;
  final VoidCallback? onTapReply;
  final VoidCallback? onOpenThread;
  final ValueChanged<MessageAttachmentOpenRequest>? onOpenAttachment;

  @override
  Widget build(BuildContext context) {
    final isThreadView =
        ConversationPresentationScope.maybeOf(context)?.isThreadView ?? false;
    final attachments = attachmentsForBubble(message.content);
    final threadInfo = message.threadInfo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        BubbleAttachmentSection(
          attachments: attachments,
          messageStableKey: message.stableKey,
          theme: theme,
          variant: BubbleAttachmentSectionVariant.visualMedia,
          maxWidth: theme.maxBubbleWidth,
          onOpenAttachment: onOpenAttachment,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showSenderName) ...[
                SenderHeader(
                  senderName:
                      message.sender.name ?? 'User ${message.sender.uid}',
                  gender: message.sender.gender,
                ),
                const SizedBox(height: senderHeaderBodyGap),
              ],
              if (message.replyToMessage != null) ...[
                ReplyQuote(reply: message.replyToMessage!, onTap: onTapReply),
                const SizedBox(height: 4),
              ],
              TextBubbleMessageBody(message: message, theme: theme),
              if (!isThreadView &&
                  threadInfo != null &&
                  threadInfo.replyCount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ThreadIndicator(
                    threadInfo: threadInfo,
                    onTap: onOpenThread,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
