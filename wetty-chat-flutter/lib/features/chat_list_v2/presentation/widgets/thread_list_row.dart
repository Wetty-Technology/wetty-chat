import 'package:flutter/cupertino.dart';

import '../../../../app/theme/style_config.dart';
import '../../../../shared/presentation/app_avatar.dart';
import '../../../chats/chat_timestamp_formatter.dart';
import '../../../chats/models/message_models.dart';
import '../../../chats/models/message_preview_formatter.dart';
import '../../../chats/threads/models/thread_models.dart';

/// A single row in the thread list displaying a thread summary.
///
/// Layout matches the PWA's ThreadListRow:
/// - Overlay avatar (big = chat group, small = root message sender)
/// - Line 1: root message preview text (muted color) + timestamp
/// - Line 2: last reply "sender: message" + unread badge
class ThreadListRow extends StatelessWidget {
  const ThreadListRow({super.key, required this.thread, this.onTap});

  final ThreadListItem thread;
  final VoidCallback? onTap;

  static const double _primaryAvatarSize = 48;
  static const double _secondaryAvatarSize = 26;

  @override
  Widget build(BuildContext context) {
    final chatName = thread.chatName.isNotEmpty
        ? thread.chatName
        : 'Chat ${thread.chatId}';

    final dateText = formatChatListTimestamp(context, thread.lastReplyAt);
    final rootPreview = _rootMessagePreview();
    final lastReplyText = _lastReplyPreviewText();
    final lastReplySender = thread.lastReply?.sender.name ?? 'User';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _OverlayAvatar(
                  chatName: chatName,
                  chatAvatar: thread.chatAvatar,
                  senderName: thread.threadRootMessage.sender.name ?? 'Unknown',
                  senderAvatar: thread.threadRootMessage.sender.avatarUrl,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Line 1: root message preview + timestamp
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              rootPreview,
                              style: appSecondaryTextStyle(
                                context,
                                fontSize: AppFontSizes.body,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (dateText != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                dateText,
                                style: appSecondaryTextStyle(
                                  context,
                                  fontSize: AppFontSizes.meta,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      // Line 2: last reply preview + unread badge
                      _buildLastReplyLine(
                        context,
                        lastReplySender,
                        lastReplyText,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  CupertinoIcons.chevron_right,
                  size: 16,
                  color: CupertinoColors.systemGrey3,
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 72),
          child: Container(
            height: 0.5,
            color: CupertinoColors.separator.resolveFrom(context),
          ),
        ),
      ],
    );
  }

  /// Root message preview for line 1, falls back to sender name.
  String _rootMessagePreview() {
    final root = thread.threadRootMessage;
    final preview = formatMessagePreview(
      message: root.message,
      messageType: root.messageType,
      sticker: root.sticker,
      attachments: root.attachments,
      isDeleted: root.isDeleted,
      mentions: root.mentions,
    );
    if (preview.isNotEmpty) return preview;
    return root.sender.name ?? 'Unknown';
  }

  /// Last reply preview text for line 2.
  String _lastReplyPreviewText() {
    final lastReply = thread.lastReply;
    if (lastReply == null) return '';
    return formatMessagePreview(
      message: lastReply.message,
      messageType: lastReply.messageType,
      sticker: lastReply.stickerEmoji != null
          ? StickerSummary(
              id: 'thread-preview-${thread.threadRootId}',
              emoji: lastReply.stickerEmoji,
            )
          : null,
      firstAttachmentKind: lastReply.firstAttachmentKind,
      isDeleted: lastReply.isDeleted,
      mentions: lastReply.mentions,
    );
  }

  Widget _buildLastReplyLine(
    BuildContext context,
    String senderName,
    String previewText,
  ) {
    final unreadCount = thread.unreadCount;
    final hasPreview = previewText.isNotEmpty;

    return Row(
      children: [
        Expanded(
          child: hasPreview
              ? Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$senderName: ',
                        style: appTextStyle(
                          context,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextSpan(text: previewText),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appTextStyle(
                    context,
                    fontSize: AppFontSizes.bodySmall,
                  ),
                )
              : Text(
                  '${thread.replyCount} repl${thread.replyCount == 1 ? 'y' : 'ies'}',
                  maxLines: 1,
                  style: appSecondaryTextStyle(
                    context,
                    fontSize: AppFontSizes.bodySmall,
                  ),
                ),
        ),
        if (unreadCount > 0) _unreadBadge(context, unreadCount),
      ],
    );
  }

  Widget _unreadBadge(BuildContext context, int count) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: CupertinoColors.systemRed,
        borderRadius: BorderRadius.circular(10),
      ),
      constraints: const BoxConstraints(minWidth: 20),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: appOnDarkTextStyle(
          context,
          fontSize: AppFontSizes.unreadBadge,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Overlay avatar: large circle for the chat group with a small circle
/// for the root message sender positioned at the top-right.
class _OverlayAvatar extends StatelessWidget {
  const _OverlayAvatar({
    required this.chatName,
    this.chatAvatar,
    required this.senderName,
    this.senderAvatar,
  });

  final String chatName;
  final String? chatAvatar;
  final String senderName;
  final String? senderAvatar;

  static const double _primarySize = ThreadListRow._primaryAvatarSize;
  static const double _secondarySize = ThreadListRow._secondaryAvatarSize;
  static const double _ringWidth = 2;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _primarySize + _ringWidth,
      height: _primarySize + _ringWidth,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Primary avatar: chat/group
          Positioned(
            left: 0,
            bottom: 0,
            child: _buildCircleAvatar(
              context,
              size: _primarySize,
              name: chatName,
              imageUrl: chatAvatar,
              fontSize: 20,
            ),
          ),
          // Secondary avatar: root message sender (top-right)
          Positioned(
            top: -_ringWidth,
            right: -_ringWidth,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: CupertinoColors.systemBackground.resolveFrom(context),
                  width: _ringWidth,
                ),
              ),
              child: _buildCircleAvatar(
                context,
                size: _secondarySize,
                name: senderName,
                imageUrl: senderAvatar,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircleAvatar(
    BuildContext context, {
    required double size,
    required String name,
    String? imageUrl,
    double fontSize = 14,
  }) {
    return AppAvatar(
      name: name,
      imageUrl: imageUrl,
      size: size,
      memCacheWidth: (size * 2).toInt(),
      fallbackBackgroundColor: CupertinoColors.systemGrey4.resolveFrom(context),
      fallbackTextStyle: appOnDarkTextStyle(
        context,
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
