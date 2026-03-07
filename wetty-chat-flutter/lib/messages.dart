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
    if (!_hasMore || _isLoadingMore || _isLoading || _messages.isEmpty) return;
    final pos = _scrollController.position;
    if (pos.pixels <= 200) {
      _loadMoreMessages();
    }
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
        _messages.addAll(res.messages);
        _nextCursor = res.nextCursor;
        _isLoading = false;
        _errorMessage = null;
      });
      // Scroll to bottom once the list has built enough items (ListView.builder is lazy)
      Future.delayed(const Duration(milliseconds: 200), () {
        if (!mounted) return;
        if (_scrollController.hasClients) {
          final pos = _scrollController.position;
          _scrollController.jumpTo(pos.maxScrollExtent);
        }
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
    final oldestId = _messages.first.id;
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
        _messages.insertAll(0, newMessages);
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
      setState(() => _messages.add(msg));
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
        // messages part and send message part
        children: [
          Expanded(child: _buildBody()),
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
      return const Center(child: Text(
        'No messages yet',
        style: TextStyle(fontSize: 20),
      ));
    }
    final showTopLoader = _hasMore && _isLoadingMore;
    return RefreshIndicator(
      onRefresh: () => _hasMore ? _loadMoreMessages() : Future.value(),
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _messages.length + (showTopLoader ? 1 : 0),
        itemBuilder: (context, index) {
          if (showTopLoader && index == 0) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final msgIndex = showTopLoader ? index - 1 : index;
          final msg = _messages[msgIndex];
          return _MessageRow(message: msg);
        },
      ),
    );
  }

  // send message: input field and send button
  Widget _buildInput() {
    return Padding(
      padding: const EdgeInsets.all(8),
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
