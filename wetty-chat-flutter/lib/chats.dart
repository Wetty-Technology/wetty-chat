import 'package:flutter/cupertino.dart';
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
  static const int _chatsSize = 11;
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
      final res = await fetchChats(limit: _chatsSize);
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
      final res = await fetchChats(limit: _chatsSize, after: lastId);
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
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text(title),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: addChat,
          child: const Icon(CupertinoIcons.add),
        ),
      ),
      child: SafeArea(child: _buildBody()),
    );
  }

  // body of chats page
  Widget _buildBody() {
    if (isLoading) {
      return const Center(child: CupertinoActivityIndicator());
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
              CupertinoButton.filled(
                onPressed: _loadChats,
                child: const Text('Retry'),
              ),
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
      itemCount: chats.length,
      separatorBuilder: (_, _) => const Padding(
        padding: EdgeInsets.only(left: 72),
        child: Divider(height: 0.5, color: CupertinoColors.separator),
      ),
      itemBuilder: (context, index) {
        final chat = chats[index];
        final chatName = chat.name?.isNotEmpty == true
            ? chat.name!
            : 'Chat ${chat.id}';
        // Format date
        String? dateText;
        if (chat.lastMessageAt != null) {
          try {
            final dt = DateTime.parse(chat.lastMessageAt!);
            final now = DateTime.now();
            if (dt.day == now.day &&
                dt.month == now.month &&
                dt.year == now.year) {
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

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (_) => ChatDetailPage(
                chatId: chat.id,
                chatName: chat.name ?? 'Chat ${chat.id}',
              ),
            ),
          ),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            // each chat item
            child: Row(
              children: [
                // TODO: change avatar to group avatar
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
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
                // Chat info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: chat name + date
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
                      // Bottom row: sender: last message + unread count
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              hasMessage ? '$senderName: $lastMsg' : '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                color: CupertinoColors.secondaryLabel
                                    .resolveFrom(context),
                              ),
                            ),
                          ),
                          if (unreadCount > 0)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: CupertinoColors.activeBlue,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$unreadCount',
                                style: const TextStyle(
                                  color: CupertinoColors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Disclosure indicator
                const Icon(
                  CupertinoIcons.chevron_right,
                  size: 16,
                  color: CupertinoColors.systemGrey3,
                ),
              ],
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
    final result = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('New chat'),
        content: Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CupertinoTextField(
            controller: nameController,
            placeholder: 'Chat name (optional)',
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: false,
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
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
        );
        setState(() => chats.insert(0, newChat));
        if (mounted) {
          _showToast('Chat created');
        }
      } else {
        if (mounted) {
          _showToast('Server error: ${response.body}');
        }
      }
    } catch (e) {
      if (mounted) {
        _showToast('Network error: $e');
      }
    }
  }

  /// Shows a brief toast-style overlay since Cupertino has no SnackBar.
  void _showToast(String message) {
    final overlay = Navigator.of(context).overlay;
    if (overlay == null) return;
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
}

/// Simple animated toast widget for Cupertino context.
class _ToastWidget extends StatefulWidget {
  const _ToastWidget({required this.message, required this.onDismiss});
  final String message;
  final VoidCallback onDismiss;

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> {
  double _opacity = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) setState(() => _opacity = 1);
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _opacity = 0);
      Future.delayed(const Duration(milliseconds: 300), widget.onDismiss);
    });
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: _opacity,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey.withAlpha(230),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            widget.message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: CupertinoColors.white, fontSize: 14),
          ),
        ),
      ),
    );
  }
}

/// Cupertino-style thin separator line.
class Divider extends StatelessWidget {
  const Divider({super.key, this.height = 1, this.color});
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: color ?? CupertinoColors.separator.resolveFrom(context),
    );
  }
}
