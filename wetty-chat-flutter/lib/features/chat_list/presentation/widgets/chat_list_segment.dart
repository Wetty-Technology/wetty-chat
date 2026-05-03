import 'package:flutter/cupertino.dart';
import 'package:chahua/l10n/app_localizations.dart';

import '../../../../app/theme/style_config.dart';

enum ChatListTab { all, groups, threads }

/// A segmented control for switching between chat list tabs.
///
/// Renders a [CupertinoSlidingSegmentedControl] with optional unread badges
/// next to each tab label. When [showAllTab] is false, only the Groups and
/// Threads segments are displayed.
class ChatListSegment extends StatelessWidget {
  const ChatListSegment({
    super.key,
    required this.activeTab,
    required this.onTabChanged,
    required this.showAllTab,
    this.allUnreadCount = 0,
    this.groupsUnreadCount = 0,
    this.threadsUnreadCount = 0,
  });

  final ChatListTab activeTab;
  final ValueChanged<ChatListTab> onTabChanged;
  final bool showAllTab;
  final int allUnreadCount;
  final int groupsUnreadCount;
  final int threadsUnreadCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final children = <ChatListTab, Widget>{
      if (showAllTab)
        ChatListTab.all: _SegmentLabel(
          label: l10n.all,
          unreadCount: allUnreadCount,
        ),
      ChatListTab.groups: _SegmentLabel(
        label: l10n.groups,
        unreadCount: groupsUnreadCount,
      ),
      ChatListTab.threads: _SegmentLabel(
        label: l10n.threads,
        unreadCount: threadsUnreadCount,
      ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: CupertinoSlidingSegmentedControl<ChatListTab>(
        groupValue: activeTab,
        onValueChanged: (value) {
          if (value != null) onTabChanged(value);
        },
        children: children,
      ),
    );
  }
}

class _SegmentLabel extends StatelessWidget {
  const _SegmentLabel({required this.label, this.unreadCount = 0});

  final String label;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    if (unreadCount <= 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          label,
          style: appMetaTextStyle(
            context,
            color: context.appColors.textPrimary,
          ),
        ),
      );
    }

    final badgeText = unreadCount > 99 ? '99+' : '$unreadCount';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: appMetaTextStyle(
              context,
              color: context.appColors.textPrimary,
            ),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: context.appColors.unreadBadge,
              borderRadius: BorderRadius.circular(8),
            ),
            constraints: const BoxConstraints(minWidth: 16),
            child: Text(
              badgeText,
              textAlign: TextAlign.center,
              style: appOnDarkTextStyle(
                context,
                color: context.appColors.unreadBadgeText,
                fontSize: AppFontSizes.unreadBadge,
                fontWeight: AppFontWeights.semibold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
