import 'package:flutter/cupertino.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../config/api_config.dart';
import '../../data/models/message_models.dart';
import '../shared/widgets.dart';
import '../group_members/group_members_view.dart';
import '../group_settings/group_settings_view.dart';
import 'chat_detail_viewmodel.dart';
import 'message_row.dart';

/// Chat detail screen: message list (oldest at top, newest at bottom) and send input.
class ChatDetailPage extends StatefulWidget {
  const ChatDetailPage({
    super.key,
    required this.chatId,
    required this.chatName,
    this.unreadCount = 0,
  });

  final String chatId;
  final String chatName;
  final int unreadCount;

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  late final ChatDetailViewModel _viewModel;
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  final ScrollController _inputScrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  static const double _titleBarHeight = 70.0;

  @override
  void initState() {
    super.initState();
    _viewModel = ChatDetailViewModel(
      chatId: widget.chatId,
      unreadCount: widget.unreadCount,
    );
    _viewModel.addListener(_onViewModelChanged);
    _itemPositionsListener.itemPositions.addListener(_onItemPositionsChanged);
    _viewModel.loadMessages();
    final draft = _viewModel.loadDraft();
    if (draft != null) _textController.text = draft;
  }

  @override
  void dispose() {
    _saveDraft();
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    _itemPositionsListener.itemPositions.removeListener(
      _onItemPositionsChanged,
    );
    _inputScrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  String? _lastJumpedId;

  void _onViewModelChanged() {
    if (!mounted) return;
    
    // Check if we need to jump to the first unread message
    if (_viewModel.firstUnreadMessageId != null && 
        _viewModel.firstUnreadMessageId != _lastJumpedId) {
      _lastJumpedId = _viewModel.firstUnreadMessageId;
      // We wait for a bit to ensure the list is rendered
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _jumpToMessage(_lastJumpedId!);
      });
    }

    setState(() {});
  }

  void _saveDraft() {
    _viewModel.saveDraft(_textController.text);
  }

  void _onItemPositionsChanged() {
    if (_viewModel.isLoadingMore ||
        _viewModel.isLoading ||
        _viewModel.displayItems.isEmpty) {
      return;
    }

    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;

    // Show jump-to-bottom button when scrolled away from newest messages.
    // In reverse mode, index 0 is at the bottom.
    final isBottomVisible = positions.any((p) => p.index == 0);
    _viewModel.updateScrollToBottom(!isBottomVisible);

    // Load more when reaching the end (highest index)
    final maxIndex = positions
        .map((p) => p.index)
        .reduce((a, b) => a > b ? a : b);
    final totalCount =
        _viewModel.displayItems.length + (_viewModel.hasMoreMessages ? 1 : 0);

    if (maxIndex >= totalCount - 5) {
      _viewModel.loadMoreMessages();
    }

    // Track read status
    for (final pos in positions) {
      // If at least 50% of the message is visible (simplified)
      if (pos.itemLeadingEdge < 0.9 && pos.itemTrailingEdge > 0.1) {
        final idx = pos.index;
        if (idx < _viewModel.displayItems.length) {
          final msg = _viewModel.displayItems[idx];
          _viewModel.onMessageVisible(msg.id);
        }
      }
    }
  }

  void _scrollToBottom() {
    _itemScrollController.scrollTo(
      index: 0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _clearInputMessage() {
    _textController.clear();
    _viewModel.clearInputState();
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    switch (_viewModel.inputState) {
      case InputEditing(:final message):
        if (text == message.message) return;
        try {
          await _viewModel.editMessage(message.id, text);
          if (!mounted) return;
          _clearInputMessage();
        } catch (e) {
          if (mounted) _showErrorDialog('$e');
        }

      case InputReplying(:final message):
        _clearInputMessage();
        _viewModel.clearDraft();
        try {
          await _viewModel.sendMessage(text, replyToId: message.id);
          _scrollToBottom();
        } catch (e) {
          if (mounted) _showErrorDialog('$e');
        }

      case InputEmpty():
        _clearInputMessage();
        _viewModel.clearDraft();
        try {
          await _viewModel.sendMessage(text);
          _scrollToBottom();
        } catch (e) {
          if (mounted) _showErrorDialog('$e');
        }
    }
  }

  Future<void> _jumpToMessage(String messageId) async {
    final found = await _viewModel.jumpToMessage(messageId);
    if (!found || !mounted) return;

    final idx = _viewModel.displayItems.indexWhere((m) => m.id == messageId);
    if (idx < 0) return;

    // Helper for precise centering scroll.
    void performRefinedScroll(int targetIdx) {
      final positions = _itemPositionsListener.itemPositions.value;
      final targetPos = positions.where((p) => p.index == targetIdx).toList();
      if (targetPos.isNotEmpty) {
        final pos = targetPos.first;
        final h = pos.itemTrailingEdge - pos.itemLeadingEdge;
        _itemScrollController.scrollTo(
          index: targetIdx,
          alignment: 0.5 - h,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }

    // If the item is already visible, center it immediately.
    final currentVisible = _itemPositionsListener.itemPositions.value
        .where((p) => p.index == idx)
        .toList();
    if (currentVisible.isNotEmpty) {
      performRefinedScroll(idx);
      return;
    }

    // Item not visible. Wait for a frame to ensure SPL recognizes the new data.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final idx2 = _viewModel.displayItems.indexWhere((m) => m.id == messageId);
      if (idx2 < 0) return;

      // Bring item into viewport.
      _itemScrollController.jumpTo(index: idx2, alignment: 0.5);

      // Yield to let the layout engine report new positions.
      await Future.delayed(Duration.zero);
      if (!mounted) return;

      var p = _itemPositionsListener.itemPositions.value
          .where((pos) => pos.index == idx2)
          .toList();

      // Retry if layout is slow (rare).
      if (p.isEmpty) {
        await Future.delayed(const Duration(milliseconds: 16));
        if (!mounted) return;
        p = _itemPositionsListener.itemPositions.value
            .where((pos) => pos.index == idx2)
            .toList();
      }

      if (p.isNotEmpty) {
        final h = p.first.itemTrailingEdge - p.first.itemLeadingEdge;
        _itemScrollController.scrollTo(
          index: idx2,
          alignment: 0.5 - h,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showErrorDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showMessageActions(MessageItem msg) {
    if (msg.isDeleted) return;
    final isOwn = msg.sender.uid == curUserId;

    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _viewModel.setReplyTo(msg);
            },
            child: const Text('Reply'),
          ),
          if (isOwn)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _viewModel.startEditing(msg);
                _textController.text = msg.message ?? '';
              },
              child: const Text('Edit'),
            ),
          if (isOwn)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(context);
                _confirmDelete(msg);
              },
              child: const Text('Delete'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _confirmDelete(MessageItem msg) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _viewModel.deleteMessage(msg.id);
              } catch (e) {
                if (mounted) _showErrorDialog('$e');
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatName = widget.chatName.isEmpty
        ? 'Chat ${widget.chatId}'
        : widget.chatName;
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _saveDraft();
      },
      child: CupertinoPageScaffold(
        backgroundColor: const Color(0xFFECE5DD),
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Stack(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          _buildBody(),
                          if (_viewModel.showScrollToBottom)
                            Positioned(
                              right: 16,
                              bottom: 16,
                              child: CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: _scrollToBottom,
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.systemGrey5
                                        .resolveFrom(context),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: CupertinoColors.systemGrey
                                            .withAlpha(80),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    CupertinoIcons.chevron_down,
                                    size: 20,
                                    color: CupertinoColors.label.resolveFrom(
                                      context,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: _buildInput(),
                    ),
                  ],
                ),
              ),
              // Gradient title bar overlay
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(0, 0.5),
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFECE5DD),
                        Color(0xDFECE5DD),
                        Color(0xCCECE5DD),
                        Color(0x80ECE5DD),
                        Color(0x40ECE5DD),
                        Color(0x00ECE5DD),
                      ],
                      stops: [0.0, 0.5, 0.6, 0.8, 0.9, 1.0],
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: SizedBox(
                      height: _titleBarHeight,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 36),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Text(
                              chatName,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Positioned(
                              left: 8,
                              child: CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  _saveDraft();
                                  Navigator.pop(context);
                                },
                                child: const Icon(
                                  CupertinoIcons.back,
                                  size: 28,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 8,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () => Navigator.push(
                                      context,
                                      CupertinoPageRoute(
                                        builder: (_) => GroupMembersPage(
                                          chatId: widget.chatId,
                                        ),
                                      ),
                                    ),
                                    child: const Icon(
                                      CupertinoIcons.person_2_fill,
                                      size: 22,
                                    ),
                                  ),
                                  CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () => Navigator.push(
                                      context,
                                      CupertinoPageRoute(
                                        builder: (_) => GroupSettingsPage(
                                          chatId: widget.chatId,
                                          currentName: widget.chatName,
                                        ),
                                      ),
                                    ),
                                    child: const Icon(
                                      CupertinoIcons.gear_solid,
                                      size: 22,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
                onPressed: _viewModel.loadMessages,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_viewModel.displayItems.isEmpty) {
      return const Center(
        child: Text('No messages yet', style: TextStyle(fontSize: 20)),
      );
    }
    final showTopLoader =
        _viewModel.nextCursor != null && _viewModel.isLoadingMore;
    final items = _viewModel.displayItems;
    final itemCount = items.length + (showTopLoader ? 1 : 0);

    return ScrollablePositionedList.builder(
      itemScrollController: _itemScrollController,
      itemPositionsListener: _itemPositionsListener,
      reverse: true,
      padding: const EdgeInsets.only(top: _titleBarHeight),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (showTopLoader && index == itemCount - 1) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CupertinoActivityIndicator()),
          );
        }

        final msg = items[index];
        final isHighlighted = _viewModel.highlightedMessageId == msg.id;

        bool showSenderName = true;
        if (index < items.length - 1) {
          final next = items[index + 1];
          if (next.sender.uid == msg.sender.uid) {
            showSenderName = false;
          }
        }

        bool showAvatar = true;
        if (index > 0) {
          final prev = items[index - 1];
          if (prev.sender.uid == msg.sender.uid) {
            showAvatar = false;
          }
        }

        final isFirstUnread = _viewModel.firstUnreadMessageId == msg.id;

        final messageRow = MessageRow(
          key: ValueKey(msg.id),
          message: msg,
          isHighlighted: isHighlighted,
          onLongPress: () => _showMessageActions(msg),
          onReply: () => _viewModel.setReplyTo(msg),
          onTapReply: msg.replyToMessage != null
              ? () => _jumpToMessage(msg.replyToMessage!.id)
              : null,
          showSenderName: showSenderName,
          showAvatar: showAvatar,
        );

        if (isFirstUnread) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildUnreadDivider(),
              messageRow,
            ],
          );
        }

        return messageRow;
      },
    );
  }

  Widget _buildUnreadDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(child: Divider(color: CupertinoColors.systemGrey4)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey4.resolveFrom(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Unread Messages',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: CupertinoColors.white,
              ),
            ),
          ),
          const Expanded(child: Divider(color: CupertinoColors.systemGrey4)),
        ],
      ),
    );
  }

  Widget _buildInput() {
    final hasPreview = _viewModel.inputState is! InputEmpty;

    return Column(
      children: [
        Divider(height: 0.5, color: CupertinoColors.separator),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      // TODO: implement attachment sheet
                    },
                    child: Icon(
                      CupertinoIcons.add_circled,
                      color: CupertinoColors.activeBlue.resolveFrom(context),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemBackground.resolveFrom(
                          context,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: CupertinoColors.systemGrey4.resolveFrom(
                            context,
                          ),
                          width: 1.0,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          switch (_viewModel.inputState) {
                            InputReplying(:final message) => _replyToMsg(
                              title:
                                  'Replying to ${message.sender.name ?? 'User ${message.sender.uid}'}',
                              body: message.message ?? '',
                            ),
                            InputEditing(:final message) => _buildPreviewBar(
                              title: 'Edit Message',
                              body: message.message ?? '',
                            ),
                            InputEmpty() => const SizedBox.shrink(),
                          },
                          if (hasPreview)
                            Container(
                              height: 0.5,
                              color: CupertinoColors.separator.resolveFrom(
                                context,
                              ),
                            ),
                          CupertinoScrollbar(
                            controller: _inputScrollController,
                            child: CupertinoTextField(
                              controller: _textController,
                              scrollController: _inputScrollController,
                              placeholder: 'Message',
                              maxLines: 5,
                              minLines: 1,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: CupertinoColors.activeBlue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.paperplane_fill,
                        size: 20,
                        color: CupertinoColors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _replyToMsg({required String title, required String body}) {
    _textController.clear();
    return _buildPreviewBar(title: title, body: body);
  }

  Widget _buildPreviewBar({required String title, required String body}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey5.resolveFrom(context),
        border: const Border(
          left: BorderSide(color: CupertinoColors.activeBlue, width: 3),
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: CupertinoColors.activeBlue,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              ],
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(30, 30),
            onPressed: _clearInputMessage,
            child: Icon(
              CupertinoIcons.xmark_circle_fill,
              size: 20,
              color: CupertinoColors.systemGrey3.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }
}
