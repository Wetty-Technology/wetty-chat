import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/style_config.dart';
import '../../chats/models/message_api_mapper.dart';
import '../application/sticker_pack_detail_view_model.dart';
import '../data/sticker_api_service.dart';

/// Pushes a full-page modal for adding a sticker to a pack.
void showAddStickerPage(
  BuildContext context, {
  required String packId,
  required String filePath,
  required String fileName,
  required Uint8List fileBytes,
}) {
  Navigator.of(context).push(
    CupertinoPageRoute(
      fullscreenDialog: true,
      builder: (_) => AddStickerPage(
        packId: packId,
        filePath: filePath,
        fileName: fileName,
        fileBytes: fileBytes,
      ),
    ),
  );
}

class AddStickerPage extends ConsumerStatefulWidget {
  const AddStickerPage({
    super.key,
    required this.packId,
    required this.filePath,
    required this.fileName,
    required this.fileBytes,
  });

  final String packId;
  final String filePath;
  final String fileName;
  final Uint8List fileBytes;

  @override
  ConsumerState<AddStickerPage> createState() => _AddStickerPageState();
}

class _AddStickerPageState extends ConsumerState<AddStickerPage> {
  final _emojiController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isUploading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emojiController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _onAdd() async {
    final emoji = _emojiController.text.trim();
    if (emoji.isEmpty) {
      setState(() {
        _errorMessage = 'Emoji is required.';
      });
      return;
    }

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      final name = _nameController.text.trim();
      final dto = await ref
          .read(stickerApiServiceProvider)
          .uploadSticker(
            widget.packId,
            filePath: widget.filePath,
            fileName: widget.fileName,
            emoji: emoji,
            name: name.isNotEmpty ? name : null,
          );
      final sticker = dto.toDomain();

      ref
          .read(stickerPackDetailViewModelProvider(widget.packId).notifier)
          .addSticker(sticker);

      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Upload failed. Please try again.';
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Add Sticker'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _isUploading ? null : _onAdd,
          child: _isUploading
              ? const CupertinoActivityIndicator()
              : const Text(
                  'Add',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
        ),
      ),
      child: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const SizedBox(height: 24),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    widget.fileBytes,
                    width: 160,
                    height: 160,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 24),
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: CupertinoColors.destructiveRed,
                        fontSize: AppFontSizes.bodySmall,
                      ),
                    ),
                  ),
                CupertinoTextField(
                  controller: _emojiController,
                  placeholder: 'Emoji e.g. \u{1F60A}',
                  textAlign: TextAlign.center,
                  enabled: !_isUploading,
                ),
                const SizedBox(height: 12),
                CupertinoTextField(
                  controller: _nameController,
                  placeholder: 'Name (optional)',
                  maxLength: 255,
                  enabled: !_isUploading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
