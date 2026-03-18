import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_application_1/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

import 'api_config.dart';
import 'draft_store.dart';
import 'group_members.dart';
import 'group_settings.dart';
import 'models.dart';

Future<ListMessagesResponse> fetchMessages(
  String chatId, {
  int? max,
  String? before,
}) async {
  final query = <String, String>{};
  if (max != null) query['max'] = max.toString();
  if (before != null && before.isNotEmpty) query['before'] = before;
  final uri = Uri.parse(
    '$apiBaseUrl/chats/$chatId/messages',
  ).replace(queryParameters: query.isEmpty ? null : query);
  final response = await http.get(uri, headers: apiHeaders);
  if (response.statusCode != 200) {
    throw Exception(
      'Failed to load messages: ${response.statusCode} ${response.body}',
    );
  }
  final res = ListMessagesResponse.fromJson(
    jsonDecode(response.body) as Map<String, dynamic>,
  );
  print('Fetched ${res.messages.length} messages for chat $chatId');
  for (var m in res.messages) {
    print(' - [${m.id}] ${m.sender.name}: ${m.message}');
  }

  return res;
}

Future<MessageItem> sendMessage(
  String chatId,
  String text, {
  String? replyToId,
}) async {
  final uri = Uri.parse('$apiBaseUrl/chats/$chatId/messages');
  final clientGeneratedId =
      '${DateTime.now().millisecondsSinceEpoch}-${Uri.base.hashCode}';
  final body = <String, dynamic>{
    'message': text,
    'message_type': 'text',
    'client_generated_id': clientGeneratedId,
  };
  if (replyToId != null) body['reply_to_id'] = int.parse(replyToId);
  final response = await http.post(
    uri,
    headers: apiHeaders,
    body: jsonEncode(body),
  );
  if (response.statusCode != 201) {
    throw Exception(
      'Failed to send message: ${response.statusCode} ${response.body}',
    );
  }
  return MessageItem.fromJson(
    jsonDecode(response.body) as Map<String, dynamic>,
  );
}

Future<MessageItem> editMessage(
  String chatId,
  String messageId,
  String newText,
) async {
  final uri = Uri.parse('$apiBaseUrl/chats/$chatId/messages/$messageId');
  final response = await http.patch(
    uri,
    headers: apiHeaders,
    body: jsonEncode({'message': newText}),
  );
  if (response.statusCode != 200) {
    throw Exception(
      'Failed to edit message: ${response.statusCode} ${response.body}',
    );
  }
  return MessageItem.fromJson(
    jsonDecode(response.body) as Map<String, dynamic>,
  );
}

Future<void> deleteMessage(String chatId, String messageId) async {
  final uri = Uri.parse('$apiBaseUrl/chats/$chatId/messages/$messageId');
  final response = await http.delete(uri, headers: apiHeaders);
  if (response.statusCode != 204) {
    throw Exception(
      'Failed to delete message: ${response.statusCode} ${response.body}',
    );
  }
}

// ---------------------------------------------------------------------------
// InputState – the three mutually exclusive states for the input bar
// ---------------------------------------------------------------------------

sealed class InputState {}

class InputEmpty extends InputState {}

class InputReplying extends InputState {
  final MessageItem message;
  InputReplying(this.message);
}

class InputEditing extends InputState {
  final MessageItem message;
  InputEditing(this.message);
}

// ---------------------------------------------------------------------------
// ChatDetailPage
// ---------------------------------------------------------------------------

/// Chat detail screen: message list (oldest at top, newest at bottom) and send input.
/// Scroll up loads older messages via [nextCursor] / before cursor.
class ChatDetailPage extends StatefulWidget {
  const ChatDetailPage({
    super.key,
    required this.chatId,
    required this.chatName,
  });

  final String chatId;
  final String chatName;

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final List<MessageItem> _messages = [];
  String? _nextCursor;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  bool _showScrollToBottom = false;
  InputState _inputState = InputEmpty();
  String? _highlightedMessageId;
  late ScrollController _scrollController;
  final ScrollController _inputScrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  // static const int _messagesSize = 15;

  bool get _hasMore => _nextCursor != null && _nextCursor!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _loadMessages();
    // Restore saved draft
    final draft = DraftStore.instance.getDraft(widget.chatId);
    if (draft != null) _textController.text = draft;
  }

  @override
  void dispose() {
    // Save draft on dispose as a fallback
    _saveDraft();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _inputScrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _saveDraft() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      DraftStore.instance.setDraft(widget.chatId, text);
    } else {
      DraftStore.instance.clearDraft(widget.chatId);
    }
  }

  void _onScroll() {
    final pos = _scrollController.position;
    // Show jump-to-bottom button when scrolled away from newest messages.
    final shouldShow = pos.pixels > 300;
    if (shouldShow != _showScrollToBottom) {
      setState(() => _showScrollToBottom = shouldShow);
    }
    if (!_hasMore || _isLoadingMore || _isLoading || _messages.isEmpty) return;
    // In a reversed list, maxScrollExtent is the TOP (oldest messages).
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      _loadMoreMessages();
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<void> _loadMessages() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _nextCursor = null;
    });
    try {
      // TODO: can set max number of messages to fetch
      final res = await fetchMessages(widget.chatId);
      if (!mounted) return;
      setState(() {
        _messages.clear();
        _messages.addAll(res.messages.reversed);
        _nextCursor = res.nextCursor;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _loadMoreMessages() async {
    if (!_hasMore || _isLoadingMore || _messages.isEmpty) return;
    final oldestId = _messages.last.id;
    setState(() => _isLoadingMore = true);
    try {
      final res = await fetchMessages(widget.chatId, before: oldestId);
      if (!mounted) return;
      final existingIds = _messages.map((m) => m.id).toSet();
      final newMessages = res.messages
          .where((m) => !existingIds.contains(m.id))
          .toList();
      setState(() {
        _messages.addAll(newMessages.reversed);
        _nextCursor = res.nextCursor;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  void _setReplyTo(MessageItem msg) {
    setState(() => _inputState = InputReplying(msg));
  }

  // used when the cancel button is clicked
  void _clearMessage() {
    _textController.clear();
    setState(() => _inputState = InputEmpty());
  }

  void _startEditing(MessageItem msg) {
    setState(() {
      _inputState = InputEditing(msg);
      _textController.text = msg.message ?? '';
    });
  }

  void _jumpToMessage(String messageId) {
    final idx = _messages.indexWhere((m) => m.id == messageId);
    if (idx < 0) return; // message not loaded
    // In a reversed list, index 0 is at the bottom.
    // Estimate position: each item ~80px tall, but we use ensureVisible-like approach.
    // We'll use a rough estimate and let the scroll settle.
    final estimatedOffset = idx * 70.0;
    _scrollController.animateTo(
      estimatedOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
    // Highlight the message briefly
    setState(() => _highlightedMessageId = messageId);
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _highlightedMessageId = null);
    });
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final state = _inputState;
    switch (state) {
      case InputEditing(:final message):
        // if the edited msg is the same as the original msg, no change
        if (text == message.message) return;
        try {
          final updated = await editMessage(widget.chatId, message.id, text);
          if (!mounted) return;
          setState(() {
            final idx = _messages.indexWhere((m) => m.id == message.id);
            if (idx >= 0) _messages[idx] = updated;
          });
        } catch (e) {
          if (mounted) _showErrorDialog('Failed to edit: $e');
        }

      case InputReplying(:final message):
        try {
          final msg = await sendMessage(
            widget.chatId,
            text,
            replyToId: message.id,
          );
          if (!mounted) return;
          setState(() => _messages.insert(0, msg));
          _scrollToBottom();
        } catch (e) {
          if (mounted) _showErrorDialog('Failed to send: $e');
        }

      case InputEmpty():
        try {
          final msg = await sendMessage(widget.chatId, text);
          if (!mounted) return;
          setState(() => _messages.insert(0, msg));
          _scrollToBottom();
        } catch (e) {
          if (mounted) _showErrorDialog('Failed to send: $e');
        }
    }

    _clearMessage();
    DraftStore.instance.clearDraft(widget.chatId);
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

  // ---- Edit / Delete actions ----
  void _showMessageActions(MessageItem msg) {
    if (msg.isDeleted) return;
    final isOwn = msg.sender.uid == curUserId;

    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        actions: [
          // Reply — available for all messages
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _setReplyTo(msg);
            },
            child: const Text('Reply'),
          ),
          if (isOwn)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _startEditing(msg);
              },
              child: const Text('Edit'),
            ),
          // Delete — only own messages
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
                await deleteMessage(widget.chatId, msg.id);
                if (!mounted) return;
                setState(() {
                  _messages.removeWhere((m) => m.id == msg.id);
                });
              } catch (e) {
                if (mounted) {
                  showCupertinoDialog(
                    context: context,
                    builder: (_) => CupertinoAlertDialog(
                      title: const Text('Error'),
                      content: Text('Failed to delete: $e'),
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
              // Main content column (messages + input)
              SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          // messages
                          _buildBody(),
                          // scroll to bottom button
                          if (_showScrollToBottom)
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
                        Color(0xFFECE5DD), // solid
                        Color(0xDFECE5DD),
                        Color(0xCCECE5DD),
                        Color(0x80ECE5DD),
                        Color(0x40ECE5DD),
                        Color(0x00ECE5DD), // transparent
                      ],
                      // stops: [0.0, 1.0],
                      stops: [0.0, 0.5, 0.6, 0.8, 0.9, 1.0],
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: SizedBox(
                      height: 70,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 36),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Centered title (independent of buttons)
                            Text(
                              chatName,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            // Back button on left
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
                            // Action buttons on right
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
    if (_isLoading) {
      return const Center(child: CupertinoActivityIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              CupertinoButton.filled(
                onPressed: _loadMessages,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_messages.isEmpty) {
      return const Center(
        child: Text('No messages yet', style: TextStyle(fontSize: 20)),
      );
    }
    final showTopLoader = _hasMore && _isLoadingMore;
    final itemCount = _messages.length + (showTopLoader ? 1 : 0);
    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: EdgeInsets.zero,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (showTopLoader && index == itemCount - 1) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CupertinoActivityIndicator()),
          );
        }
        final msg = _messages[index];
        final isHighlighted = _highlightedMessageId == msg.id;
        return _MessageRow(
          key: ValueKey(msg.id),
          message: msg,
          isHighlighted: isHighlighted,
          onLongPress: () => _showMessageActions(msg),
          onReply: () => _setReplyTo(msg),
          onTapReply: msg.replyToMessage != null
              ? () => _jumpToMessage(msg.replyToMessage!.id)
              : null,
        );
      },
    );
  }

  Widget _buildInput() {
    // when editing or replying to a message, show the preview of that message
    final hasPreview = _inputState is! InputEmpty;

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
                  // attachment button
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    // padding: const EdgeInsets.fromLTRB(1, 1, 1, 0),
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
                  // Unified input box (Preview + Text field)
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
                          // preview bar: switch input state to get msg /and sender
                          switch (_inputState) {
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
                            // use container as divider
                            Container(
                              height: 0.5,
                              color: CupertinoColors.separator.resolveFrom(
                                context,
                              ),
                            ),
                          // text field
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
                              decoration: null, // use container decoration
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Send button
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

  // show preview bar when replying or editing
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
          // cancel button
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(30, 30),
            onPressed: _clearMessage,
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

// ---------------------------------------------------------------------------
// _MessageRow — message bubble with avatar, inline time, reply quote,
// swipe-to-reply gesture
// ---------------------------------------------------------------------------

class _MessageRow extends StatefulWidget {
  const _MessageRow({
    super.key,
    required this.message,
    this.isHighlighted = false,
    this.onLongPress,
    this.onReply,
    this.onTapReply,
  });

  final MessageItem message;
  final bool isHighlighted;
  final VoidCallback? onLongPress;
  final VoidCallback? onReply;
  final VoidCallback? onTapReply;

  @override
  State<_MessageRow> createState() => _MessageRowState();
}

class _MessageRowState extends State<_MessageRow>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0;
  bool _hasTriggeredReply = false;
  static const double _replyThreshold = 60;

  bool get _isMe => widget.message.sender.uid == curUserId;

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      // Only allow dragging to the left (negative offset)
      _dragOffset = (_dragOffset + details.delta.dx).clamp(
        -_replyThreshold * 1.3,
        0,
      );
    });
    if (!_hasTriggeredReply && _dragOffset <= -_replyThreshold) {
      _hasTriggeredReply = true;
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (_hasTriggeredReply) {
      widget.onReply?.call();
    }
    _hasTriggeredReply = false;
    setState(() => _dragOffset = 0);
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final screenWidth = MediaQuery.of(context).size.width;
    final msgText = message.message ?? '';
    final senderName = message.sender.name ?? 'User ${message.sender.uid}';
    final timeStr = _formatTime(message.createdAt);

    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;

    final bubbleColor = _isMe
        ? CupertinoColors.activeBlue
        : (isDark ? CupertinoColors.systemGrey5.darkColor : Color(0xfff0f0f0));
    final textColor = _isMe
        ? CupertinoColors.white
        : CupertinoColors.label.resolveFrom(context);
    // edited label, time
    final metaColor = _isMe
        ? CupertinoColors.white.withAlpha(180)
        : CupertinoColors.secondaryLabel.resolveFrom(context);

    // Avatar initial
    final initial = (senderName.isNotEmpty ? senderName[0] : '?').toUpperCase();

    final maxBubbleWidth = screenWidth * 0.75;

    // edited label, time
    final editedLabel = message.isEdited ? 'edited ' : '';
    Widget timeWidget = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message.isEdited)
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Text(
              'edited',
              style: TextStyle(color: metaColor, fontSize: 11),
            ),
          ),
        Text(timeStr, style: TextStyle(color: metaColor, fontSize: 11)),
      ],
    );

    // Measure time width to create a matching invisible spacer.
    final timePainter = TextPainter(
      text: TextSpan(
        text: ' $editedLabel$timeStr',
        style: const TextStyle(fontSize: 11),
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: double.infinity);
    final timeSpacerWidth = timePainter.width + 8;

    // msg content, edited label, date/time
    // Link detection colors
    final linkColor = _isMe
        ? CupertinoColors.white
        : CupertinoColors.activeBlue;

    Widget bubbleContent = Stack(
      children: [
        Text.rich(
          TextSpan(
            children: [
              ..._buildLinkedSpans(
                msgText,
                TextStyle(color: textColor, fontSize: 15),
                linkColor,
              ),
              WidgetSpan(child: SizedBox(width: timeSpacerWidth, height: 14)),
            ],
          ),
        ),
        Positioned(right: 0, bottom: 0, child: timeWidget),
      ],
    );

    // the whole bubble
    Widget fullContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // sender name
        if (!_isMe)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(
              senderName,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: textColor,
              ),
            ),
          ),
        // reply quote
        if (message.replyToMessage != null)
          GestureDetector(
            onTap: widget.onTapReply,
            child: _buildReplyQuote(context, message.replyToMessage!),
          ),
        // message content
        bubbleContent,
      ],
    );

    Widget bubble = Container(
      constraints: BoxConstraints(maxWidth: maxBubbleWidth),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(_isMe ? 18 : 4),
          bottomRight: Radius.circular(_isMe ? 4 : 18),
        ),
      ),
      child: fullContent,
    );

    Widget avatar = Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: isDark
            ? CupertinoColors.systemGrey4.darkColor
            : CupertinoColors.systemGrey4.color,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: CupertinoColors.white,
        ),
      ),
    );

    // Reply icon that appears on the right when swiping
    final replyIconOpacity = (_dragOffset.abs() / _replyThreshold).clamp(
      0.0,
      1.0,
    );

    Widget messageRow = AnimatedContainer(
      duration: const Duration(milliseconds: 600),
      decoration: BoxDecoration(
        color: widget.isHighlighted
            ? CupertinoColors.systemYellow.withAlpha(60)
            : const Color(0x00000000),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Row(
          mainAxisAlignment: _isMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: _isMe
              ? [bubble, const SizedBox(width: 6), avatar]
              : [avatar, const SizedBox(width: 6), bubble],
        ),
      ),
    );

    return GestureDetector(
      onLongPress: widget.onLongPress,
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          // Reply icon behind the message
          Positioned(
            right: 12,
            child: Opacity(
              opacity: replyIconOpacity,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey5.resolveFrom(context),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.reply,
                  size: 22,
                  color: CupertinoColors.activeBlue,
                ),
              ),
            ),
          ),
          // The actual message, translated by drag offset
          AnimatedContainer(
            duration: _dragOffset == 0
                ? const Duration(milliseconds: 200)
                : Duration.zero,
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(_dragOffset, 0, 0),
            child: messageRow,
          ),
        ],
      ),
    );
  }

  Widget _buildReplyQuote(BuildContext context, ReplyToMessage reply) {
    final replySender = reply.sender.name ?? 'User ${reply.sender.uid}';
    final replyText = reply.isDeleted
        ? 'Message deleted'
        : (reply.message ?? '');

    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;

    final quoteBackgroundColor = _isMe
        ? Color.lerp(CupertinoColors.activeBlue, const Color(0xFF000000), 0.15)!
        : (isDark
              ? CupertinoColors.systemGrey4.darkColor
              : CupertinoColors.systemGrey5.color);
    final quoteBorderColor = _isMe
        ? CupertinoColors.white.withAlpha(150)
        : CupertinoColors.activeBlue;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: quoteBackgroundColor,
        border: Border(left: BorderSide(color: quoteBorderColor, width: 3)),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(4),
          bottomRight: Radius.circular(4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            replySender,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: quoteBorderColor,
            ),
          ),
          Text(
            replyText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: _isMe
                  ? CupertinoColors.white.withAlpha(200)
                  : CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Link-detection helper ----
  static final RegExp _urlRegex = RegExp(
    r'(https?://[^\s<>]+|www\.[^\s<>]+)',
    caseSensitive: false,
  );

  List<InlineSpan> _buildLinkedSpans(
    String text,
    TextStyle baseStyle,
    Color linkColor,
  ) {
    final spans = <InlineSpan>[];
    int lastEnd = 0;
    for (final match in _urlRegex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, match.start),
            style: baseStyle,
          ),
        );
      }
      final url = match.group(0)!;
      final recognizer = TapGestureRecognizer()
        ..onTap = () {
          final uri = url.startsWith('http') ? url : 'https://$url';
          launchUrl(Uri.parse(uri), mode: LaunchMode.externalApplication);
        };
      spans.add(
        TextSpan(
          text: url,
          style: baseStyle.copyWith(
            color: linkColor,
            decoration: TextDecoration.underline,
            decorationColor: linkColor,
          ),
          recognizer: recognizer,
        ),
      );
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: baseStyle));
    }
    // If no links found, return a single span
    if (spans.isEmpty) {
      spans.add(TextSpan(text: text, style: baseStyle));
    }
    return spans;
  }

  String _formatTime(String iso) {
    if (iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}
