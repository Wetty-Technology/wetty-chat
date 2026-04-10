import 'package:flutter/cupertino.dart';

import '../../../../../app/theme/style_config.dart';

class ChatListRow extends StatelessWidget {
  const ChatListRow({
    super.key,
    required this.chatName,
    required this.timestampText,
    required this.unreadCount,
    required this.onTap,
    this.senderName,
    this.lastMessageText,
    this.draftText,
    this.isMuted = false,
  });

  final String chatName;
  final String? timestampText;
  final int unreadCount;
  final VoidCallback onTap;
  final String? senderName;
  final String? lastMessageText;
  final String? draftText;
  final bool isMuted;

  @override
  Widget build(BuildContext context) {
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
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(
                    color: CupertinoColors.systemGrey4,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  // TODO: use image instead of text
                  child: Text(
                    chatName.isNotEmpty ? chatName[0].toUpperCase() : '?',
                    style: appOnDarkTextStyle(
                      context,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    chatName,
                                    style: appChatEntryTitleTextStyle(context),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isMuted)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 4),
                                    child: Icon(
                                      CupertinoIcons.bell_slash,
                                      size: 14,
                                      color: CupertinoColors.systemGrey
                                          .resolveFrom(context),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (timestampText != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: Text(
                                timestampText!,
                                style: appSecondaryTextStyle(
                                  context,
                                  fontSize: AppFontSizes.meta,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      _Subtitle(
                        senderName: senderName,
                        lastMessageText: lastMessageText,
                        draftText: draftText,
                        unreadCount: unreadCount,
                        isMuted: isMuted,
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
}

class _Subtitle extends StatelessWidget {
  const _Subtitle({
    required this.senderName,
    required this.lastMessageText,
    required this.draftText,
    required this.unreadCount,
    this.isMuted = false,
  });

  final String? senderName;
  final String? lastMessageText;
  final String? draftText;
  final int unreadCount;
  final bool isMuted;

  bool get _hasDraft => draftText != null;
  bool get _hasMessagePreview =>
      lastMessageText != null && lastMessageText!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (_hasDraft) {
      return Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '[Draft] ',
                    style: appTextStyle(
                      context,
                      fontSize: AppFontSizes.bodySmall,
                      color: CupertinoColors.destructiveRed,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextSpan(
                    text: draftText,
                    style: appSecondaryTextStyle(
                      context,
                      fontSize: AppFontSizes.bodySmall,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (unreadCount > 0)
            _UnreadBadge(count: unreadCount, isMuted: isMuted),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _hasMessagePreview
              ? Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$senderName: ',
                        style: appTextStyle(
                          context,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(text: lastMessageText),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appSecondaryTextStyle(
                    context,
                    fontSize: AppFontSizes.bodySmall,
                  ),
                )
              : Text(
                  'No messages yet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appSecondaryTextStyle(
                    context,
                    fontSize: AppFontSizes.bodySmall,
                  ),
                ),
        ),
        if (unreadCount > 0) _UnreadBadge(count: unreadCount, isMuted: isMuted),
      ],
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count, this.isMuted = false});

  final int count;
  final bool isMuted;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isMuted ? CupertinoColors.systemGrey : CupertinoColors.systemRed,
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
