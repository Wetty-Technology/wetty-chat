import 'package:chahua/features/conversation/shared/domain/conversation_message_v2.dart';
import 'package:chahua/features/conversation/media/presentation/attachment_viewer_request.dart';
import 'package:chahua/features/conversation/shared/presentation/conversation_presentation_scope.dart';
import 'package:flutter/cupertino.dart';

import '../../domain/bubble_theme_v2.dart';
import '../parts/attachment/bubble_attachment_section.dart';
import '../parts/meta_footer.dart';
import '../parts/reply_quote.dart';
import '../parts/thread_indicator.dart';
import 'text_bubble_v2.dart';

class TextBubbleVisualOnlyContent extends StatelessWidget {
  const TextBubbleVisualOnlyContent({
    super.key,
    required this.message,
    required this.theme,
    this.onTapReply,
    this.onOpenThread,
    this.onOpenAttachment,
  });

  final ConversationMessageV2 message;
  final BubbleThemeV2 theme;
  final VoidCallback? onTapReply;
  final VoidCallback? onOpenThread;
  final ValueChanged<MessageAttachmentOpenRequest>? onOpenAttachment;

  @override
  Widget build(BuildContext context) {
    final isThreadView =
        ConversationPresentationScope.maybeOf(context)?.isThreadView ?? false;
    final attachments = attachmentsForBubble(message.content);
    final children = <Widget>[
      if (message.replyToMessage != null)
        ReplyQuote(
          reply: message.replyToMessage!,
          variant: ReplyQuoteVariant.overSticker,
          onTap: onTapReply,
        ),
      BubbleAttachmentSection(
        attachments: attachments,
        messageStableKey: message.stableKey,
        theme: theme,
        variant: BubbleAttachmentSectionVariant.visualMedia,
        overlayFooter: MetaFooter(
          message: message,
          color: CupertinoColors.white,
        ),
        clipBorderRadius: BorderRadius.circular(18),
        onOpenAttachment: onOpenAttachment,
      ),
    ];

    final threadInfo = message.threadInfo;
    if (!isThreadView && threadInfo != null && threadInfo.replyCount > 0) {
      children.add(const SizedBox(height: 4));
      children.add(
        ThreadIndicator(threadInfo: threadInfo, onTap: onOpenThread),
      );
    }

    return Column(
      crossAxisAlignment: theme.isMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}
