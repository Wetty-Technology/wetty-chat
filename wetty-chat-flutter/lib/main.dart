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

  ChatListItem({
    required this.id,
    this.name,
    this.lastMessageAt,
  });

  factory ChatListItem.fromJson(Map<String, dynamic> json) {
    return ChatListItem(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String?,
      lastMessageAt: json['last_message_at'] as String?,
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
      chats: list.map((e) => ChatListItem.fromJson(e as Map<String, dynamic>)).toList(),
      nextCursor: json['next_cursor']?.toString(),
    );
  }
}

Future<ListChatsResponse> fetchChats({int? limit, String? after}) async {
  final query = <String, String>{};
  if (limit != null) query['limit'] = limit.toString();
  if (after != null && after.isNotEmpty) query['after'] = after;
  final uri = Uri.parse('$_apiBaseUrl/chats').replace(queryParameters: query.isEmpty ? null : query);
  final response = await http.get(uri, headers: _apiHeaders);
  if (response.statusCode != 200) {
    throw Exception('Failed to load chats: ${response.statusCode} ${response.body}');
  }
  return ListChatsResponse.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
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
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final res = await fetchChats();
      if (!mounted) return;
      setState(() {
        chats = res.chats;
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
      itemCount: chats.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final chat = chats[index];
        final name = chat.name?.isNotEmpty == true ? chat.name! : 'Unnamed chat';
        String? subtitle;
        if (chat.lastMessageAt != null) {
          try {
            final dt = DateTime.parse(chat.lastMessageAt!);
            final now = DateTime.now();
            if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
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
        );
      },
    );
  }

  Future<http.Response> createChat({String? name}) {
    final url = Uri.parse('$_apiBaseUrl/group');
    return http.post(
      url,
      headers: _apiHeaders,
      body: jsonEncode({"name": name}),
    );
  }

  Future<void> addChat() async {
    try {
      final response = await createChat(name: "New Chat");
      if (response.statusCode == 201) {
        await _loadChats();
      } else {
        if (mounted) {
          setState(() => errorMessage = 'Server error: ${response.body}');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => errorMessage = 'Network error: $e');
      }
    }
  }
}
