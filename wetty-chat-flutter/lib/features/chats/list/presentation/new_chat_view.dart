import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import '../data/chat_repository.dart';

/// Page to create a new chat group.
class NewChatPage extends StatefulWidget {
  const NewChatPage({super.key});

  @override
  State<NewChatPage> createState() => _NewChatPageState();
}

class _NewChatPageState extends State<NewChatPage> {
  final _nameController = TextEditingController();
  final _repository = ChatRepository();
  bool _isCreating = false;

  TextStyle _inputStyle(BuildContext context) {
    return TextStyle(color: CupertinoColors.label.resolveFrom(context));
  }

  TextStyle _placeholderStyle(BuildContext context) {
    return TextStyle(
      color: CupertinoColors.placeholderText.resolveFrom(context),
    );
  }

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
      final chat = await _repository.createChat(
        name: name.isEmpty ? null : name,
      );
      if (!mounted) return;
      if (chat != null) {
        context.pop(chat);
      } else {
        _showError('Chat creation did not return a result.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isCreating = false);
      _showError('Network error: $e');
    }
  }

  void _showError(String message) {
    setState(() => _isCreating = false);
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
          onPressed: () => context.pop(),
          child: const Icon(CupertinoIcons.back, size: 28),
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
                  style: _inputStyle(context),
                  placeholderStyle: _placeholderStyle(context),
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
