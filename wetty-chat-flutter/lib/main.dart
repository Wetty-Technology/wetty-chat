import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// --- API config (no auth yet; test header) ---
const String _apiBaseUrl = 'http://10.42.3.100:3000';
Map<String, String> get _apiHeaders => {
  'Content-Type': 'application/json',
  'Accept': 'application/json',
  'X-User-Id': '12345',
};

// --- GET /chats response models ---
class ChatListItem {
  final String id;
  final String? name;
  final String? lastMessageAt;
  final String? lastMessagePreview;
  final String? lastMessageSenderName;

  ChatListItem({
    required this.id,
    this.name,
    this.lastMessageAt,
    this.lastMessagePreview,
    this.lastMessageSenderName,
  });

  factory ChatListItem.fromJson(Map<String, dynamic> json) {
    return ChatListItem(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String?,
      lastMessageAt: json['last_message_at'] as String?,
      lastMessagePreview: json['last_message_preview'] as String?,
      lastMessageSenderName: json['last_message_sender_name'] as String?,
    );
  }
}

class ListChatsResponse {
  final List<ChatListItem> chats;
  final String? nextCursor;

  ListChatsResponse({required this.chats, this.nextCursor});

  factory ListChatsResponse.fromJson(Map<String, dynamic> json) {
    final list = json['chats'] as List<dynamic>? ?? [];
    return ListChatsResponse(
      chats: list
          .map((e) => ChatListItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      nextCursor: json['next_cursor']?.toString(),
    );
  }
}

Future<ListChatsResponse> fetchChats({int? limit, String? after}) async {
  final query = <String, String>{};
  if (limit != null) query['limit'] = limit.toString();
  if (after != null && after.isNotEmpty) query['after'] = after;
  final uri = Uri.parse(
    '$_apiBaseUrl/chats',
  ).replace(queryParameters: query.isEmpty ? null : query);
  final response = await http.get(uri, headers: _apiHeaders);
  if (response.statusCode != 200) {
    throw Exception(
      'Failed to load chats: ${response.statusCode} ${response.body}',
    );
  }
  return ListChatsResponse.fromJson(
    jsonDecode(response.body) as Map<String, dynamic>,
  );
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: ChatPage());
  }
}

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
  late TextEditingController nameController;

  bool get hasMoreChats => nextCursor != null && nextCursor!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    nameController = TextEditingController();
    _loadChats();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    nameController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!hasMoreChats || isLoadingMore || isLoading) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      _loadMoreChats();
    }
  }

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
        print("nextCursor: $nextCursor");
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
        print("nextCursor: $nextCursor");
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
      controller: _scrollController,
      itemCount: chats.length + (hasMoreChats && isLoadingMore ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index >= chats.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final chat = chats[index];
        final name = chat.name?.isNotEmpty == true
            ? chat.name!
            : 'Chat ${chat.id}';
        String dateStr = '';
        if (chat.lastMessageAt != null) {
          try {
            final dt = DateTime.parse(chat.lastMessageAt!);
            final now = DateTime.now();
            if (dt.day == now.day &&
                dt.month == now.month &&
                dt.year == now.year) {
              dateStr =
                  '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
            } else {
              dateStr = '${dt.month}/${dt.day}';
            }
          } catch (_) {
            dateStr = chat.lastMessageAt ?? '';
          }
        }
        String subtitle;
        if (chat.lastMessagePreview != null &&
            chat.lastMessagePreview!.isNotEmpty) {
          final sender = chat.lastMessageSenderName?.isNotEmpty == true
              ? '${chat.lastMessageSenderName}: '
              : '';
          final preview = chat.lastMessagePreview!.length > 80
              ? '${chat.lastMessagePreview!.substring(0, 80)}…'
              : chat.lastMessagePreview!;
          subtitle = '$sender$preview';
        } else if (chat.lastMessageAt != null) {
          subtitle = '';
        } else {
          subtitle = 'No messages';
        }
        return ListTile(
          title: Text(name),
          subtitle: subtitle.isEmpty
              ? null
              : Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: dateStr.isNotEmpty
              ? Text(dateStr, style: Theme.of(context).textTheme.bodySmall)
              : null,
        );
      },
    );
  }

  Future<http.Response> createChat({String? name}) async {
    final url = Uri.parse('$_apiBaseUrl/group');
    return http.post(
      url,
      headers: _apiHeaders,
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
    // nameController.dispose();
    try {
      final response = await createChat(name: name.isEmpty ? null : name);
      print("response: $response");
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
