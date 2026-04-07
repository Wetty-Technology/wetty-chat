import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/style_config.dart';
import '../../../../core/session/dev_session_store.dart';
import '../../../../shared/presentation/app_divider.dart';
import '../application/conversation_composer_view_model.dart';
import '../data/attachment_service.dart';
import '../domain/conversation_scope.dart';

class ConversationComposerBar extends ConsumerStatefulWidget {
  const ConversationComposerBar({
    super.key,
    required this.scope,
    this.onMessageSent,
  });

  final ConversationScope scope;
  final Future<void> Function()? onMessageSent;

  @override
  ConsumerState<ConversationComposerBar> createState() =>
      _ConversationComposerBarState();
}

class _ConversationComposerBarState
    extends ConsumerState<ConversationComposerBar> {
  final ScrollController _inputScrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();

  late final AttachmentService _attachmentService;
  ProviderSubscription<ConversationComposerState>? _composerSubscription;
  bool _isUploadingAttachment = false;

  @override
  void initState() {
    super.initState();
    _attachmentService = AttachmentService(ref.read(devSessionProvider));

    _composerSubscription = ref.listenManual<ConversationComposerState>(
      conversationComposerViewModelProvider(widget.scope),
      (_, next) => _syncControllerText(next.draft),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _composerSubscription?.close();
    _inputScrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _syncControllerText(String draft) {
    if (_textController.text == draft) {
      return;
    }
    _textController.value = TextEditingValue(
      text: draft,
      selection: TextSelection.collapsed(offset: draft.length),
    );
  }

  Future<void> _sendMessage() async {
    final composer = ref.read(
      conversationComposerViewModelProvider(widget.scope),
    );
    final composerNotifier = ref.read(
      conversationComposerViewModelProvider(widget.scope).notifier,
    );
    if (_isUploadingAttachment) {
      _showErrorDialog('File upload is still in progress.');
      return;
    }
    if (composer.isEditing && composer.attachments.isNotEmpty) {
      _showErrorDialog('Editing does not support attachments yet.');
      return;
    }
    if (_textController.text.trim().isEmpty && composer.attachments.isEmpty) {
      return;
    }
    try {
      await composerNotifier.send(text: _textController.text);
      _textController.clear();
      await widget.onMessageSent?.call();
    } catch (error) {
      if (mounted) {
        _showErrorDialog('$error');
      }
    }
  }

  Future<(int?, int?)> _decodeImageSize(Uint8List bytes) async {
    try {
      final completer = Completer<ui.Image>();
      ui.decodeImageFromList(bytes, completer.complete);
      final image = await completer.future.timeout(const Duration(seconds: 2));
      final size = (image.width, image.height);
      image.dispose();
      return size;
    } catch (_) {
      return (null, null);
    }
  }

  String _guessContentType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.bmp')) return 'image/bmp';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.json')) return 'application/json';
    if (lower.endsWith('.zip')) return 'application/zip';
    return 'application/octet-stream';
  }

  Future<void> _pickAttachment() async {
    if (kIsWeb || !Platform.isWindows) {
      _showErrorDialog(
        'Attachment upload is currently only implemented on Windows.',
      );
      return;
    }
    if (_isUploadingAttachment) {
      return;
    }
    final file = await openFile();
    if (file == null) {
      return;
    }
    setState(() {
      _isUploadingAttachment = true;
    });
    try {
      final filename = file.name;
      final contentType = _guessContentType(filename);
      final size = await file.length();
      Uint8List? previewBytes;
      int? width;
      int? height;
      if (contentType.startsWith('image/') && size <= 8 * 1024 * 1024) {
        previewBytes = await file.readAsBytes();
        final dimensions = await _decodeImageSize(previewBytes);
        width = dimensions.$1;
        height = dimensions.$2;
      }

      final uploadInfo = await _attachmentService.requestUploadUrl(
        filename: filename,
        contentType: contentType,
        size: size,
        width: width,
        height: height,
      );
      await _attachmentService.uploadFileToS3(
        uploadUrl: uploadInfo.uploadUrl,
        file: File(file.path),
        contentType: contentType,
      );
      if (!mounted) {
        return;
      }
      ref
          .read(conversationComposerViewModelProvider(widget.scope).notifier)
          .addUploadedAttachment(
            ComposerAttachment(
              id: uploadInfo.attachmentId,
              name: filename,
              mimeType: contentType,
              previewBytes: previewBytes,
            ),
          );
    } catch (error) {
      if (mounted) {
        _showErrorDialog('Upload failed: $error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingAttachment = false;
        });
      }
    }
  }

  void _showErrorDialog(String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final composer = ref.watch(
      conversationComposerViewModelProvider(widget.scope),
    );
    final isEditing = composer.isEditing;
    final canAttach = !isEditing && !_isUploadingAttachment;
    final canSend =
        !_isUploadingAttachment &&
        (composer.draft.trim().isNotEmpty || composer.attachments.isNotEmpty);
    final barBackground = CupertinoColors.secondarySystemGroupedBackground
        .resolveFrom(context);

    return ColoredBox(
      color: barBackground,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppDivider(),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: canAttach ? _pickAttachment : null,
                  child: Icon(
                    CupertinoIcons.add_circled,
                    color: canAttach
                        ? CupertinoColors.activeBlue.resolveFrom(context)
                        : CupertinoColors.systemGrey2.resolveFrom(context),
                    size: 28,
                  ),
                ),
                if (_isUploadingAttachment)
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 2),
                    child: CupertinoActivityIndicator(radius: 8),
                  ),
                const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemBackground.resolveFrom(
                        context,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: CupertinoColors.systemGrey4.resolveFrom(context),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildComposerPreview(composer),
                        if (composer.attachments.isNotEmpty)
                          _buildAttachmentPreview(composer),
                        CupertinoScrollbar(
                          controller: _inputScrollController,
                          child: CupertinoTextField(
                            controller: _textController,
                            scrollController: _inputScrollController,
                            onChanged: (value) {
                              unawaited(
                                ref
                                    .read(
                                      conversationComposerViewModelProvider(
                                        widget.scope,
                                      ).notifier,
                                    )
                                    .updateDraft(value),
                              );
                            },
                            placeholder: 'Message',
                            maxLines: 5,
                            minLines: 1,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(36, 36),
                  onPressed: canSend ? _sendMessage : null,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: canSend
                          ? CupertinoColors.activeBlue.resolveFrom(context)
                          : CupertinoColors.systemGrey3.resolveFrom(context),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      CupertinoIcons.paperplane_fill,
                      size: 20,
                      color: CupertinoColors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposerPreview(ConversationComposerState composer) {
    final mode = composer.mode;
    return switch (mode) {
      ComposerReplying(:final message) => _previewBar(
        title:
            'Replying to ${message.sender.name ?? 'User ${message.sender.uid}'}',
        body: message.message ?? '',
      ),
      ComposerEditing(:final message) => _previewBar(
        title: 'Edit Message',
        body: message.message ?? '',
      ),
      ComposerIdle() => const SizedBox.shrink(),
    };
  }

  Widget _previewBar({required String title, required String body}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey5.resolveFrom(context),
        border: const Border(
          left: BorderSide(color: CupertinoColors.activeBlue, width: 3),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appTextStyle(
                    context,
                    fontWeight: FontWeight.w600,
                    fontSize: AppFontSizes.bodySmall,
                    color: CupertinoColors.activeBlue,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appSecondaryTextStyle(
                    context,
                    fontSize: AppFontSizes.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(30, 30),
            onPressed: () {
              ref
                  .read(
                    conversationComposerViewModelProvider(
                      widget.scope,
                    ).notifier,
                  )
                  .clearMode();
            },
            child: Icon(
              CupertinoIcons.xmark_circle_fill,
              size: 20,
              color: CupertinoColors.systemGrey3.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentPreview(ConversationComposerState composer) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (int index = 0; index < composer.attachments.length; index++)
            _attachmentChip(composer.attachments[index], index),
        ],
      ),
    );
  }

  Widget _attachmentChip(ComposerAttachment attachment, int index) {
    final borderColor = CupertinoColors.systemGrey4.resolveFrom(context);
    final background = CupertinoColors.systemGrey5.resolveFrom(context);
    final thumb = attachment.isImage
        ? ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.memory(
              attachment.previewBytes!,
              width: 36,
              height: 36,
              fit: BoxFit.cover,
            ),
          )
        : Icon(
            CupertinoIcons.doc,
            size: 28,
            color: CupertinoColors.activeBlue.resolveFrom(context),
          );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          thumb,
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              attachment.name,
              overflow: TextOverflow.ellipsis,
              style: appTextStyle(context, fontSize: AppFontSizes.meta),
            ),
          ),
          const SizedBox(width: 6),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(20, 20),
            onPressed: () {
              ref
                  .read(
                    conversationComposerViewModelProvider(
                      widget.scope,
                    ).notifier,
                  )
                  .removeAttachmentAt(index);
            },
            child: Icon(
              CupertinoIcons.xmark_circle_fill,
              size: 18,
              color: CupertinoColors.systemGrey2.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }
}
