import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/notifications/unread_badge_provider.dart';
import '../../../../core/settings/app_settings_store.dart';
import '../../list/presentation/chat_list_segment.dart';
import '../application/all_list_v2_view_model.dart';
import '../application/group_list_v2_view_model.dart';
import '../application/thread_list_v2_view_model.dart';
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
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  ChatListTab _effectiveTab(bool showAllTab) {
    final tab = _activeTab;
    if (tab == null) {
      return ChatListTab.groups;
    }
    if (!showAllTab && tab == ChatListTab.all) {
      return ChatListTab.groups;
    }
    return tab;
  }

  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 200) {
      return;
    }

    final settings = ref.read(appSettingsProvider);
    final activeTab = _effectiveTab(settings.showAllTab);
    if (activeTab == ChatListTab.groups) {
      final viewState = ref.read(groupListV2ViewModelProvider).value;
      if (viewState == null || !viewState.hasMore || viewState.isLoadingMore) {
        return;
      }
      ref.read(groupListV2ViewModelProvider.notifier).loadMoreGroups();
      return;
    }

    if (activeTab == ChatListTab.threads) {
      final threadState = ref.read(threadListV2ViewModelProvider).value;
      if (threadState == null ||
          !threadState.hasMore ||
          threadState.isLoadingMore) {
        return;
      }
      ref.read(threadListV2ViewModelProvider.notifier).loadMoreThreads();
      return;
    }

    if (activeTab == ChatListTab.all) {
      final allState = ref.read(allListV2ViewModelProvider);
      if (allState.isLoadingMore) {
        return;
      }
      ref.read(allListV2ViewModelProvider.notifier).loadMoreAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final showAllTab = settings.showAllTab;
    final activeTab = _effectiveTab(showAllTab);

    final unreadState = ref.watch(unreadBadgeProvider);

    final groupsUnread = unreadState.chatUnreadTotal;
    final threadsUnread = unreadState.threadUnreadTotal;
    final allUnread = unreadState.combinedUnreadTotal;

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
