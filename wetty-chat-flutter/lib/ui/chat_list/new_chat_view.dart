import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../data/models/chat_models.dart';

/// Page to create a new chat group.
class NewChatPage extends StatefulWidget {
  const NewChatPage({super.key, required this.createChat});
  final Future<http.Response> Function({String? name}) createChat;

  @override
  State<NewChatPage> createState() => _NewChatPageState();
}

class _NewChatPageState extends State<NewChatPage> {
  final _nameController = TextEditingController();
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _onCreate() async {
    if (_isCreating) return;
    setState(() => _isCreating = true);
    final name = _nameController.text.trim();
    try {
      final response = await widget.createChat(
        name: name.isEmpty ? null : name,
      );
      if (!mounted) return;
      if (response.statusCode == 201) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final id = body['id']?.toString() ?? '';
        final createdName = body['name'] as String?;
        Navigator.of(context).pop(ChatListItem(id: id, name: createdName));
      } else {
        setState(() => _isCreating = false);
        _showError('Server error: ${response.body}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCreating = false);
      _showError('Network error: $e');
    }
  }

  void _showError(String message) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('New Chat'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Back'),
        ),
      ),
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chat Name',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: _nameController,
                  placeholder: 'Optional',
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    onPressed: _isCreating ? null : _onCreate,
                    child: _isCreating
                        ? const CupertinoActivityIndicator(
                            color: CupertinoColors.white,
                          )
                        : const Text('Create'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
