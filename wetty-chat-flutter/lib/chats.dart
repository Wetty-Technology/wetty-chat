import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'api_config.dart';
import 'messages.dart';
import 'models.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  String title = "Chats";
  List<ChatListItem> chats = [];
  bool isLoading = true;
  bool isLoadingMore = false;
  String? errorMessage;
  String? nextCursor;
  static const int _pageSize = 11;
  late ScrollController _scrollController;
  late TextEditingController _nameController;

  bool get hasMoreChats => nextCursor != null && nextCursor!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _nameController = TextEditingController();
    _loadChats();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!hasMoreChats || isLoadingMore || isLoading) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      _loadMoreChats();
    }
  }

  // initial load
  Future<void> _loadChats() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      errorMessage = null;
      nextCursor = null;
    });
    try {
      final res = await fetchChats(limit: _pageSize);
      if (!mounted) return;
      setState(() {
        chats = res.chats;
        nextCursor = res.nextCursor;
        isLoading = false;
        errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = e.toString();
      });
    }
  }

  // check and load more chats when scrolling to the bottom of a page
  Future<void> _loadMoreChats() async {
    if (!hasMoreChats || isLoadingMore || chats.isEmpty) return;
    final lastId = chats.last.id;
    setState(() => isLoadingMore = true);
    try {
      final res = await fetchChats(limit: _pageSize, after: lastId);
      if (!mounted) return;
      final existingIds = chats.map((c) => c.id).toSet();
      final newChats = res.chats
          .where((c) => !existingIds.contains(c.id))
          .toList();
      setState(() {
        chats = [...chats, ...newChats];
        nextCursor = res.nextCursor;
        isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [IconButton(icon: const Icon(Icons.add), onPressed: addChat)],
      ),
      body: _buildBody(),
    );
  }

  // body of chats page
  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _loadChats, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (chats.isEmpty) {
      return const Center(child: Text('No chats yet'));
    }
    return ListView.separated(
      itemCount: chats.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final chat = chats[index];
        if (chat.name == null || chat.name!.isEmpty) {

        }
        final name = chat.name?.isNotEmpty == true
            ? chat.name!
            : 'Chat ${chat.id}';
        String? subtitle;
        if (chat.lastMessageAt != null) {
          try {
            // print("chat.lastMessageAt: ${chat.lastMessageAt}");
            final dt = DateTime.parse(chat.lastMessageAt!);
            final now = DateTime.now();
            if (dt.day == now.day &&
                dt.month == now.month &&
                dt.year == now.year) {
              subtitle = '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
            } else {
              subtitle = '${dt.month}/${dt.day}';
            }
          } catch (_) {
            subtitle = chat.lastMessageAt;
          }
        }
        return ListTile(
          title: Text(name),
          subtitle: subtitle != null ? Text(subtitle) : null,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatDetailPage(
                chatId: chat.id,
                chatName: chat.name ?? 'Chat ${chat.id}',
              ),
            ),
          ),
        );
      },
    );
  }

  // get chats
  Future<ListChatsResponse> fetchChats({int? limit, String? after}) async {
    final query = <String, String>{};
    if (limit != null) query['limit'] = limit.toString();
    if (after != null && after.isNotEmpty) query['after'] = after;
    final uri = Uri.parse(
      '$apiBaseUrl/chats',
    ).replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: apiHeaders);
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to load chats: ${response.statusCode} ${response.body}',
      );
    }
    return ListChatsResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  // create chat
  Future<http.Response> createChat({String? name}) async {
    final url = Uri.parse('$apiBaseUrl/group');
    return http.post(
      url,
      headers: apiHeaders,
      body: jsonEncode({"name": name}),
    );
  }

  Future<void> addChat() async {
    final nameController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New chat'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Chat name (optional)',
            hintText: 'Enter a name',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (result != true || !mounted) return;
    final name = nameController.text.trim();
    try {
      final response = await createChat(name: name.isEmpty ? null : name);
      // TODO: check response status code, the response code is 201 for now
      if (response.statusCode == 201) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final id = body['id']?.toString() ?? '';
        final createdName = body['name'] as String?;
        final newChat = ChatListItem(
          id: id,
          name: createdName,
          lastMessageAt: null,
          lastMessagePreview: null,
          lastMessageSenderName: null,
        );
        setState(() => chats.insert(0, newChat));
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Chat created')));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Server error: ${response.body}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Network error: $e')));
      }
    }
  }
}