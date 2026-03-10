import 'package:flutter/material.dart';
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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to send: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // let the chat name be either chat name or chat id
    final chatName = widget.chatName.isEmpty
        ? 'Chat ${widget.chatId}'
        : widget.chatName;
    return Scaffold(
      appBar: AppBar(title: Text(chatName)),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                _buildBody(),
                if (_showScrollToBottom)
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: FloatingActionButton.small(
                      onPressed: _scrollToBottom,
                      child: const Icon(Icons.arrow_downward),
                    ),
                  ),
              ],
            ),
          ),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
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
              FilledButton(
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
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // loading more messages indicator
        if (showTopLoader && index == itemCount - 1) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
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
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              decoration: const InputDecoration(
                hintText: 'Message',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(icon: const Icon(Icons.send), onPressed: _sendMessage),
        ],
      ),
    );
  }
}

// each message row: user id, message, time
class _MessageRow extends StatelessWidget {
  const _MessageRow({required this.message});

  final MessageItem message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = message.message ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // TODO: change to username?
                  'User ${message.senderUid}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(text, style: theme.textTheme.bodyMedium),
                Text(
                  _formatTime(message.createdAt),
                  style: theme.textTheme.bodySmall,
                ),
              ],
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
