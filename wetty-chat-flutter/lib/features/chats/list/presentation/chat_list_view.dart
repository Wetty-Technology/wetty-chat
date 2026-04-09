import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routing/route_names.dart';
import '../../../../app/theme/style_config.dart';
import '../../../../core/settings/app_settings_store.dart';
import '../../chat_timestamp_formatter.dart';
import '../../conversation/application/conversation_draft_store.dart';
import '../../conversation/domain/conversation_scope.dart';
import '../../conversation/domain/launch_request.dart';
import '../../models/chat_models.dart';
import '../../models/message_models.dart';
import '../../models/message_preview_formatter.dart';
import '../../threads/application/thread_list_view_model.dart';
import '../../threads/models/thread_models.dart';
import '../../threads/presentation/thread_list_row.dart';
import '../../threads/presentation/thread_list_view.dart';
import '../application/chat_list_view_model.dart';
import '../data/chat_launch_service.dart';
import 'chat_list_segment.dart';

// ---------------------------------------------------------------------------
// Merged list items for the "All" tab
// ---------------------------------------------------------------------------

/// Union type for items in the merged "All" tab list.
sealed class MergedListItem {
  DateTime? get sortTime;
}

/// Wraps a [ChatListItem] for the merged list.
class MergedChatItem extends MergedListItem {
  MergedChatItem(this.chat);
  final ChatListItem chat;

  @override
  DateTime? get sortTime => chat.lastMessageAt;
}

/// Wraps a [ThreadListItem] for the merged list.
class MergedThreadItem extends MergedListItem {
  MergedThreadItem(this.thread);
  final ThreadListItem thread;

  @override
  DateTime? get sortTime => thread.lastReplyAt;
}

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
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// Resolves the effective active tab based on current settings.
  ChatListTab _effectiveTab(bool showAllTab) {
    final tab = _activeTab;
    if (tab == null) {
      // First build: pick default based on setting.
      return showAllTab ? ChatListTab.all : ChatListTab.groups;
    }
    // If the "All" tab was removed while we were on it, fall back.
    if (!showAllTab && tab == ChatListTab.all) {
      return ChatListTab.groups;
    }
    return tab;
  }

  /// Computes the total unread count for groups (excluding muted chats).
  int _groupsUnreadCount(List<ChatListItem> chats) {
    final now = DateTime.now();
    var total = 0;
    for (final chat in chats) {
      if (chat.mutedUntil != null && chat.mutedUntil!.isAfter(now)) continue;
      total += chat.unreadCount;
    }
    return total;
  }

  /// Computes the total unread count for threads.
  int _threadsUnreadCount(List<ThreadListItem> threads) {
    var total = 0;
    for (final thread in threads) {
      total += thread.unreadCount;
    }
    return total;
  }

  /// Merges chat and thread items, sorted by most recent first.
  List<MergedListItem> _buildMergedList(
    List<ChatListItem> chats,
    List<ThreadListItem> threads,
  ) {
    final items = <MergedListItem>[
      for (final chat in chats) MergedChatItem(chat),
      for (final thread in threads) MergedThreadItem(thread),
    ];
    items.sort((a, b) {
      final aTime = a.sortTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.sortTime ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTime.compareTo(aTime);
    });
    return items;
  }

  void _onScroll() {
    final viewState = ref.read(chatListViewModelProvider).valueOrNull;
    if (viewState == null) return;
    if (!viewState.hasMore || viewState.isLoadingMore) return;

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      ref.read(chatListViewModelProvider.notifier).loadMoreChats();
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

  Future<void> _refreshChats() {
    return ref
        .read(chatListViewModelProvider.notifier)
        .refreshChats(userInitiated: true);
  }

  Future<LaunchRequest> _launchRequestForChat(ChatListItem chat) async {
    return ref.read(chatLaunchServiceProvider).resolveLaunchRequest(chat);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final showAllTab = settings.showAllTab;
    final activeTab = _effectiveTab(showAllTab);

    // Watch both providers so we can compute unread badges.
    final chatAsync = ref.watch(chatListViewModelProvider);
    final threadAsync = ref.watch(threadListViewModelProvider);

    final chatList = chatAsync.valueOrNull?.chats ?? const [];
    final threadList = threadAsync.valueOrNull?.threads ?? const [];

    final groupsUnread = _groupsUnreadCount(chatList);
    final threadsUnread = _threadsUnreadCount(threadList);
    final allUnread = groupsUnread + threadsUnread;

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
              child: _buildTabContent(activeTab, chatAsync, threadAsync),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent(
    ChatListTab tab,
    AsyncValue<ChatListViewState> chatAsync,
    AsyncValue<ThreadListViewState> threadAsync,
  ) {
    return switch (tab) {
      ChatListTab.groups => chatAsync.when(
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (error, _) => _buildErrorView(
          error,
          () => ref.invalidate(chatListViewModelProvider),
        ),
        data: (viewState) => _buildBody(viewState),
      ),
      ChatListTab.threads => const ThreadListView(embedded: true),
      ChatListTab.all => _buildAllTab(chatAsync, threadAsync),
    };
  }

  Widget _buildAllTab(
    AsyncValue<ChatListViewState> chatAsync,
    AsyncValue<ThreadListViewState> threadAsync,
  ) {
    // Show loading only when both are loading and have no data yet.
    if (chatAsync is AsyncLoading && threadAsync is AsyncLoading) {
      return const Center(child: CupertinoActivityIndicator());
    }

    // If the chat provider errored and has no data, show error.
    if (chatAsync is AsyncError && chatAsync.valueOrNull == null) {
      return _buildErrorView(
        (chatAsync as AsyncError).error,
        () => ref.invalidate(chatListViewModelProvider),
      );
    }

    final chatViewState = chatAsync.valueOrNull;
    final threadViewState = threadAsync.valueOrNull;

    final chats = chatViewState?.chats ?? const [];
    final threads = threadViewState?.threads ?? const [];

    if (chats.isEmpty && threads.isEmpty) {
      return const Center(child: Text('No chats or threads yet'));
    }

    final merged = _buildMergedList(chats, threads);
    final isLoadingMore =
        (chatViewState?.isLoadingMore ?? false) ||
        (threadViewState?.isLoadingMore ?? false);

    if (_supportsPullToRefresh) {
      return CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverRefreshControl(onRefresh: _refreshChats),
          SliverList.builder(
            itemCount: merged.length,
            itemBuilder: (context, index) =>
                _buildMergedItem(context, merged[index]),
          ),
          if (isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CupertinoActivityIndicator()),
              ),
            ),
        ],
      );
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: merged.length + (isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= merged.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CupertinoActivityIndicator()),
          );
        }
        return _buildMergedItem(context, merged[index]);
      },
    );
  }

  Widget _buildMergedItem(BuildContext context, MergedListItem item) {
    return switch (item) {
      MergedChatItem(:final chat) => _buildChatListItem(context, chat),
      MergedThreadItem(:final thread) => ThreadListRow(
        thread: thread,
        onTap: () {
          context.push(
            AppRoutes.threadDetail(
              thread.chatId,
              thread.threadRootId.toString(),
            ),
          );
        },
      ),
    };
  }

  Widget _buildErrorView(Object error, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(error.toString(), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            CupertinoButton.filled(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(ChatListViewState viewState) {
    if (viewState.errorMessage != null && viewState.chats.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(viewState.errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              CupertinoButton.filled(
                onPressed: () => ref.invalidate(chatListViewModelProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (viewState.chats.isEmpty) {
      return const Center(child: Text('No chats yet'));
    }

    if (_supportsPullToRefresh) {
      return CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverRefreshControl(onRefresh: _refreshChats),
          SliverList.builder(
            itemCount: viewState.chats.length,
            itemBuilder: (context, index) =>
                _buildChatListItem(context, viewState.chats[index]),
          ),
          if (viewState.isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CupertinoActivityIndicator()),
              ),
            ),
        ],
      );
    }

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: viewState.chats.length + (viewState.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= viewState.chats.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CupertinoActivityIndicator()),
          );
        }
        return _buildChatListItem(context, viewState.chats[index]);
      },
    );
  }

  Widget _buildChatListItem(BuildContext context, ChatListItem chat) {
    final chatName = chat.name?.isNotEmpty == true
        ? chat.name!
        : 'Chat ${chat.id}';

    final dateText = formatChatListTimestamp(context, chat.lastMessageAt);

    final lastMessage = chat.lastMessage;
    final senderName = lastMessage?.sender.name;
    final lastMsg = _messagePreviewText(lastMessage);
    final unreadCount = chat.unreadCount;
    final hasMessage = lastMessage != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            final launchRequest = await _launchRequestForChat(chat);
            if (!context.mounted) return;
            final shouldRefresh = await context.push<bool>(
              AppRoutes.chatDetail(chat.id),
              extra: {'launchRequest': launchRequest},
            );
            if (shouldRefresh == true) {
              await ref.read(chatListViewModelProvider.notifier).refreshChats();
            }
          },
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
                            child: Text(
                              chatName,
                              style: appChatEntryTitleTextStyle(context),
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
                      _buildSubtitle(
                        context,
                        chat,
                        senderName,
                        lastMsg,
                        hasMessage,
                        unreadCount,
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

  Widget _buildSubtitle(
    BuildContext context,
    ChatListItem chat,
    String? senderName,
    String? lastMsg,
    bool hasMessage,
    int unreadCount,
  ) {
    final draft = ref
        .read(conversationDraftProvider)
        .getDraft(ConversationScope.chat(chat.id));
    if (draft != null) {
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
                    text: draft,
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
          if (unreadCount > 0) _unreadBadge(unreadCount),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: hasMessage
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
                      TextSpan(text: lastMsg),
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
        if (unreadCount > 0) _unreadBadge(unreadCount),
      ],
    );
  }

  String _messagePreviewText(MessageItem? message) {
    if (message == null) return '';
    return formatMessagePreview(
      message: message.message,
      messageType: message.messageType,
      sticker: message.sticker,
      attachments: message.attachments,
      firstAttachmentKind: message.attachments.isNotEmpty
          ? message.attachments.first.kind
          : null,
      isDeleted: message.isDeleted,
      mentions: message.mentions,
    );
  }

  Widget _unreadBadge(int count) {
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
