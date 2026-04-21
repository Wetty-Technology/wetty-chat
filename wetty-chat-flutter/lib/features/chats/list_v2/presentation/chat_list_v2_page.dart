import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/notifications/unread_badge_provider.dart';
import '../../../../core/settings/app_settings_store.dart';
import '../../list/application/chat_list_view_model.dart';
import '../../list/presentation/chat_list_segment.dart';
import '../../list/presentation/models/merged_list_item.dart';
import '../../threads/application/thread_list_view_model.dart';
import 'widgets/chat_list_v2_tab_body.dart';

class ChatListV2Page extends ConsumerStatefulWidget {
  const ChatListV2Page({super.key});

  @override
  ConsumerState<ChatListV2Page> createState() => _ChatListV2PageState();
}

class _ChatListV2PageState extends ConsumerState<ChatListV2Page> {
  late final ScrollController _scrollController;
  ChatListTab? _activeTab;

  bool get _supportsPullToRefresh {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  ChatListTab _effectiveTab(bool showAllTab) {
    final tab = _activeTab;
    if (tab == null) {
      return showAllTab ? ChatListTab.all : ChatListTab.groups;
    }
    if (!showAllTab && tab == ChatListTab.all) {
      return ChatListTab.groups;
    }
    return tab;
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final showAllTab = settings.showAllTab;
    final activeTab = _effectiveTab(showAllTab);

    final chatAsync = ref.watch(chatListViewModelProvider);
    final threadAsync = ref.watch(threadListViewModelProvider);
    final unreadState = ref.watch(unreadBadgeProvider);

    final chatList = chatAsync.value?.chats ?? const [];
    final threadList = threadAsync.value?.threads ?? const [];

    final groupsUnread = unreadState.chatUnreadTotal;
    final threadsUnread = unreadState.threadUnreadTotal;
    final allUnread = unreadState.combinedUnreadTotal;
    final mergedItems = buildMergedList(chatList, threadList);

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Chats V2')),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ChatListSegment(
              activeTab: activeTab,
              showAllTab: showAllTab,
              allUnreadCount: allUnread,
              groupsUnreadCount: groupsUnread,
              threadsUnreadCount: threadsUnread,
              onTabChanged: (tab) => setState(() => _activeTab = tab),
            ),
            Expanded(
              child: ChatListV2TabBody(
                activeTab: activeTab,
                chatAsync: chatAsync,
                threadAsync: threadAsync,
                mergedItems: mergedItems,
                scrollController: _scrollController,
                supportsPullToRefresh: _supportsPullToRefresh,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
