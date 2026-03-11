import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'api_config.dart';
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
  return ListMessagesResponse.fromJson(
    jsonDecode(response.body) as Map<String, dynamic>,
  );
}

Future<MessageItem> sendMessage(String chatId, String text) async {
  final uri = Uri.parse('$apiBaseUrl/chats/$chatId/messages');
  final clientGeneratedId =
      '${DateTime.now().millisecondsSinceEpoch}-${Uri.base.hashCode}';
  final body = {
    'message': text,
    'message_type': 'text',
    'client_generated_id': clientGeneratedId,
  };
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
  late ScrollController _scrollController;
  final TextEditingController _textController = TextEditingController();
  static const int _messagesSize = 11;

  bool get _hasMore => _nextCursor != null && _nextCursor!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _loadMessages();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
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
      final res = await fetchMessages(widget.chatId, max: _messagesSize);
      if (!mounted) return;
      setState(() {
        _messages.clear();
        _messages.addAll(res.messages.reversed);
        _nextCursor = res.nextCursor;
        _isLoading = false;
        _errorMessage = null;
      });
      // No manual scroll needed — reverse: true starts at the bottom automatically.
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
      final res = await fetchMessages(
        widget.chatId,
        max: _messagesSize,
        before: oldestId,
      );
      if (!mounted) return;
      final existingIds = _messages.map((m) => m.id).toSet();
      final newMessages = res.messages
          .where((m) => !existingIds.contains(m.id))
          .toList();
      setState(() {
        // Append older messages to the end (they appear at the top in reverse mode).
        _messages.addAll(newMessages.reversed);
        _nextCursor = res.nextCursor;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    _textController.clear();
    try {
      final msg = await sendMessage(widget.chatId, text);
      if (!mounted) return;
      setState(() => _messages.insert(0, msg));
      // Scroll to newest message (offset 0 in reversed list).
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      // Cupertino doesn't have SnackBar — show an alert instead.
      if (mounted) {
        showCupertinoDialog(
          context: context,
          builder: (_) => CupertinoAlertDialog(
            title: const Text('Error'),
            content: Text('Failed to send: $e'),
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
  }

  @override
  Widget build(BuildContext context) {
    // let the chat name be either chat name or chat id
    final chatName = widget.chatName.isEmpty
        ? 'Chat ${widget.chatId}'
        : widget.chatName;
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text(chatName)),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
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
                            color: CupertinoColors.systemGrey5.resolveFrom(
                              context,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: CupertinoColors.systemGrey.withAlpha(80),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            CupertinoIcons.chevron_down,
                            size: 20,
                            color: CupertinoColors.label.resolveFrom(context),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _buildInput(),
          ],
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
        // loading more messages indicator
        if (showTopLoader && index == itemCount - 1) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CupertinoActivityIndicator()),
          );
        }
        // _messages is ordered newest-first (index 0 = newest).
        // In reverse mode, index 0 is at the visual bottom.
        final msg = _messages[index];
        return _MessageRow(message: msg);
      },
    );
  }

  // send message: input field and send button
  Widget _buildInput() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: CupertinoColors.separator.resolveFrom(context),
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: CupertinoTextField(
                controller: _textController,
                placeholder: 'Message',
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey6.resolveFrom(context),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(width: 6),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: _sendMessage,
              child: const Icon(CupertinoIcons.paperplane_fill, size: 32),
            ),
          ],
        ),
      ),
    );
  }
}

// each message row: bubble with sender, message, time, and optional reply quote
class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.message});

  final MessageItem message;

  bool get _isMe => message.sender.uid == curUserId;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final text = message.message ?? '';
    final senderName = message.sender.name ?? 'User ${message.sender.uid}';

    final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;

    // select color based on theme and message sender
    final bubbleColor = _isMe
        ? CupertinoColors.activeBlue
        : (isDark
              ? CupertinoColors.systemGrey5.darkColor
              : CupertinoColors.systemGrey5.color);
    final textColor = _isMe
        ? CupertinoColors.white
        : CupertinoColors.label.resolveFrom(context);
    final metaColor = _isMe
        ? CupertinoColors.white.withAlpha(180)
        : CupertinoColors.secondaryLabel.resolveFrom(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Row(
        //decide whether the msg appears on the right side or the left side
        mainAxisAlignment: _isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: screenWidth * 0.75),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sender name (only for others' messages)
                if (!_isMe)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      senderName,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: CupertinoColors.activeBlue.resolveFrom(context),
                      ),
                    ),
                  ),
                // Reply-to quote
                if (message.replyToMessage != null)
                  _buildReplyQuote(context, message.replyToMessage!),
                // Message text
                Text(text, style: TextStyle(color: textColor, fontSize: 15)),
                const SizedBox(height: 2),
                // Time + edited indicator
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (message.isEdited)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          'edited',
                          style: TextStyle(color: metaColor, fontSize: 11),
                        ),
                      ),
                    Text(
                      _formatTime(message.createdAt),
                      style: TextStyle(color: metaColor, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
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
              : CupertinoColors.systemGrey4.color);
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
              fontStyle: reply.isDeleted ? FontStyle.italic : FontStyle.normal,
            ),
          ),
        ],
      ),
    );
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
