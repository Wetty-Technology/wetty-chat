import 'package:flutter/cupertino.dart';
import '../shared/widgets.dart';

/// Group Settings page — edit group name, description, and save.
class GroupSettingsPage extends StatefulWidget {
  const GroupSettingsPage({
    super.key,
    required this.chatId,
    required this.currentName,
  });
  final String chatId;
  final String currentName;

  @override
  State<GroupSettingsPage> createState() => _GroupSettingsPageState();
}

class _GroupSettingsPageState extends State<GroupSettingsPage> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  final ScrollController _descScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _descScrollController.dispose();
    super.dispose();
  }

  void _onSave() {
    // TODO: call backend API to update group settings
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Group Settings'),
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
                  'Name',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                CupertinoTextField(
                  controller: _nameController,
                  placeholder: 'Group name',
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: null,
                ),
                const Divider(height: 1),
                const SizedBox(height: 24),
                const Text(
                  'Description',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                CupertinoScrollbar(
                  controller: _descScrollController,
                  child: CupertinoTextField(
                    controller: _descriptionController,
                    scrollController: _descScrollController,
                    placeholder: 'Enter group description',
                    maxLines: 4,
                    minLines: 2,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: null,
                  ),
                ),
                const Divider(height: 1),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    onPressed: _onSave,
                    child: const Text('Save Settings'),
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
