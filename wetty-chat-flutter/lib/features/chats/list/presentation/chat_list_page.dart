import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routing/route_names.dart';
import '../../../../app/theme/style_config.dart';
import '../../../../core/notifications/unread_badge_provider.dart';
import '../../../../core/settings/app_settings_store.dart';
import '../../models/chat_models.dart';
import '../../threads/application/thread_list_view_model.dart';
import '../application/chat_list_view_model.dart';
import 'chat_list_segment.dart';
import 'models/merged_list_item.dart';
import 'widgets/chat_list_tab_body.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
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
    Future.microtask(() {
      if (!mounted) {
        return;
      }
      ref.read(unreadBadgeProvider.notifier).refresh();
    });
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
      return showAllTab ? ChatListTab.all : ChatListTab.groups;
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
      final viewState = ref.read(chatListViewModelProvider).value;
      if (viewState == null || !viewState.hasMore || viewState.isLoadingMore) {
        return;
      }
      ref.read(chatListViewModelProvider.notifier).loadMoreChats();
      return;
    }

    if (activeTab == ChatListTab.threads) {
      final threadState = ref.read(threadListViewModelProvider).value;
      if (threadState == null ||
          !threadState.hasMore ||
          threadState.isLoadingMore) {
        return;
      }
      ref.read(threadListViewModelProvider.notifier).loadMoreThreads();
      return;
    }

    if (activeTab == ChatListTab.all) {
      final chatState = ref.read(chatListViewModelProvider).value;
      if (chatState != null && chatState.hasMore && !chatState.isLoadingMore) {
        ref.read(chatListViewModelProvider.notifier).loadMoreChats();
      }

      final threadState = ref.read(threadListViewModelProvider).value;
      if (threadState != null &&
          threadState.hasMore &&
          !threadState.isLoadingMore) {
        ref.read(threadListViewModelProvider.notifier).loadMoreThreads();
      }
    }
  }

  Future<void> _addChat() async {
    final newChat = await context.push<ChatListItem>(AppRoutes.newChat);
    if (newChat != null && mounted) {
      ref.read(chatListViewModelProvider.notifier).insertChat(newChat);
      _showToast('Chat created');
    }
  }

  void _showToast(String message) {
    final overlay = Navigator.of(context).overlay;
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        bottom: 80,
        left: 24,
        right: 24,
        child: _ToastWidget(message: message, onDismiss: () => entry.remove()),
      ),
    );
    overlay.insert(entry);
  }

  Future<void> _refreshLists() async {
    await Future.wait([
      ref
          .read(chatListViewModelProvider.notifier)
          .refreshChats(userInitiated: true),
      ref
          .read(threadListViewModelProvider.notifier)
          .refreshThreads(userInitiated: true),
      ref.read(unreadBadgeProvider.notifier).refresh(),
    ]);
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
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Chats'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _addChat,
          child: const Icon(
            CupertinoIcons.square_pencil,
            size: IconSizes.iconSize,
          ),
        ),
      ),
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
              child: ChatListTabBody(
                activeTab: activeTab,
                chatAsync: chatAsync,
                threadAsync: threadAsync,
                mergedItems: mergedItems,
                scrollController: _scrollController,
                supportsPullToRefresh: _supportsPullToRefresh,
                onRefresh: _refreshLists,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToastWidget extends StatefulWidget {
  const _ToastWidget({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 2), widget.onDismiss);
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          widget.message,
          textAlign: TextAlign.center,
          style: appOnDarkTextStyle(context),
        ),
      ),
    );
  }
}
