import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/api_config.dart';
import '../../config/auth_store.dart';
import '../../data/models/chat_models.dart';
import '../chat_detail/chat_detail_view.dart';
import '../settings/settings_view.dart';
import '../shared/draft_store.dart';
import '../shared/widgets.dart';
import 'chat_list_viewmodel.dart';
import 'new_chat_view.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ChatListViewModel _viewModel = ChatListViewModel();
  late final ScrollController _scrollController;

  bool get _isDesktopRefreshPlatform {
    if (kIsWeb) {
      return false;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
        return true;
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  bool get _supportsPullToRefresh {
    if (kIsWeb) {
      return false;
    }
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
    _viewModel.addListener(_onViewModelChanged);
    _viewModel.initLoadChats();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onViewModelChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onScroll() {
    if (!_viewModel.hasMore ||
        _viewModel.isLoadingMore ||
        _viewModel.isLoading) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      _viewModel.loadMoreChats();
    }
  }

  Future<void> _addChat() async {
    Future<http.Response> createChat({String? name}) async {
      final url = Uri.parse('$apiBaseUrl/group');
      return http.post(
        url,
        headers: apiHeaders,
        body: jsonEncode({'name': name}),
      );
    }

    final newChat = await Navigator.push<ChatListItem>(
      context,
      CupertinoPageRoute(builder: (_) => NewChatPage(createChat: createChat)),
    );
    if (newChat != null && mounted) {
      _viewModel.insertChat(newChat);
      _showToast('Chat created');
    }
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('退出登录？', style: TextStyle(fontFamily: 'MiSans')),
        content: const Text(
          '这会清除当前设备保存的登录状态。',
          style: TextStyle(fontFamily: 'MiSans'),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消', style: TextStyle(fontFamily: 'MiSans')),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('退出登录', style: TextStyle(fontFamily: 'MiSans')),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await AuthStore.instance.clearToken();
    }
  }

  void _showToast(String message) {
    final overlay = Navigator.of(context).overlay;
    if (overlay == null) {
      return;
    }

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
    return _viewModel.refreshChats(userInitiated: true);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.push(
            context,
            CupertinoPageRoute(builder: (_) => const SettingsPage()),
          ),
          child: const Icon(CupertinoIcons.gear),
        ),
        middle: const Text('Chats'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isDesktopRefreshPlatform)
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: _viewModel.isRefreshing ? null : _refreshChats,
                child: _viewModel.isRefreshing
                    ? const CupertinoActivityIndicator(radius: 9)
                    : const Icon(CupertinoIcons.refresh),
              ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _confirmLogout,
              child: const Icon(CupertinoIcons.square_arrow_right),
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _addChat,
              child: const Icon(CupertinoIcons.square_pencil),
            ),
          ],
        ),
      ),
      child: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading) {
      return const Center(child: CupertinoActivityIndicator());
    }
    if (_viewModel.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_viewModel.errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              CupertinoButton.filled(
                onPressed: _viewModel.initLoadChats,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_viewModel.chats.isEmpty) {
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
            itemCount: _viewModel.chats.length,
            itemBuilder: (context, index) =>
                _buildChatListItem(context, _viewModel.chats[index]),
          ),
          if (_viewModel.isLoadingMore)
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
      itemCount: _viewModel.chats.length + (_viewModel.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _viewModel.chats.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CupertinoActivityIndicator()),
          );
        }
        return _buildChatListItem(context, _viewModel.chats[index]);
      },
    );
  }

  Widget _buildChatListItem(BuildContext context, ChatListItem chat) {
    final chatName = chat.name?.isNotEmpty == true
        ? chat.name!
        : 'Chat ${chat.id}';

    String? dateText;
    if (chat.lastMessageAt != null) {
      try {
        final dt = DateTime.parse(chat.lastMessageAt!);
        final now = DateTime.now();
        if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
          dateText =
              '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        } else {
          dateText = '${dt.month}/${dt.day}';
        }
      } catch (_) {
        dateText = chat.lastMessageAt;
      }
    }

    final senderName = chat.lastMessage?.sender.name;
    final lastMsg = chat.lastMessage?.message;
    final unreadCount = chat.unreadCount;
    final hasMessage =
        (senderName != null && senderName.isNotEmpty) &&
        (lastMsg != null && lastMsg.isNotEmpty);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async {
            final shouldRefresh = await Navigator.push<bool>(
              context,
              CupertinoPageRoute(
                builder: (_) => ChatDetailPage(
                  chatId: chat.id,
                  chatName: chat.name ?? 'Chat ${chat.id}',
                  unreadCount: chat.unreadCount,
                ),
              ),
            );
            if (shouldRefresh == true) {
              await _viewModel.refreshChats();
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
                  child: Text(
                    chatName.isNotEmpty ? chatName[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: CupertinoColors.white,
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
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
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
                                style: TextStyle(
                                  fontSize: 12,
                                  color: CupertinoColors.secondaryLabel
                                      .resolveFrom(context),
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
    final draft = DraftStore.instance.getDraft(chat.id);
    if (draft != null) {
      return Row(
        children: [
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: '[Draft] ',
                    style: TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.destructiveRed,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextSpan(
                    text: draft,
                    style: TextStyle(
                      fontSize: 13,
                      color: CupertinoColors.secondaryLabel.resolveFrom(
                        context,
                      ),
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
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: lastMsg),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                )
              : Text(
                  'No messages yet',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
        ),
        if (unreadCount > 0) _unreadBadge(unreadCount),
      ],
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
        style: const TextStyle(
          fontSize: 11,
          color: CupertinoColors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
