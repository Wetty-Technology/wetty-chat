import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import '../../../../app/presentation/root_navigation.dart';
import '../../../../app/theme/style_config.dart';
import '../../detail/application/chat_draft_store.dart';
import '../../detail/presentation/chat_detail_view.dart';
import '../../models/chat_models.dart';
import '../../models/message_models.dart';
import '../application/chat_list_view_model.dart';
import 'new_chat_view.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ChatListViewModel _viewModel = ChatListViewModel();
  late final ScrollController _scrollController;

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
    final newChat = await pushRootCupertinoPage<ChatListItem>(
      context,
      NewChatPage(createChat: _viewModel.createChat),
    );
    if (newChat != null && mounted) {
      _viewModel.insertChat(newChat);
      _showToast('Chat created');
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
            final shouldRefresh = await pushRootCupertinoPage<bool>(
              context,
              ChatDetailPage(
                chatId: chat.id,
                chatName: chat.name ?? 'Chat ${chat.id}',
                unreadCount: chat.unreadCount,
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
    final draft = ChatDraftStore.instance.getDraft(chat.id);
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
    if (message == null) {
      return '';
    }

    if (message.isDeleted) {
      return '[Deleted]';
    }

    final text = message.message?.trim();
    if (text != null && text.isNotEmpty) {
      return text;
    }

    // TODO: implement options of preview text later
    if (message.attachments.any((attachment) => attachment.isImage)) {
      return '[Image]';
    }

    if (message.attachments.any((attachment) => attachment.isVideo)) {
      return '[Video]';
    }

    if (message.attachments.isNotEmpty || message.hasAttachments) {
      return '[Attachment]';
    }

    return '';
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
