import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show CircularProgressIndicator;

import '../../../../../app/theme/style_config.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../../models/message_preview_formatter.dart';
import '../../application/conversation_composer_view_model.dart';
import '../../data/attachment_picker_service.dart';
import '../../domain/conversation_message.dart';
import 'composer_audio_controls.dart';

class ComposerInputArea extends StatelessWidget {
  const ComposerInputArea({
    super.key,
    required this.composer,
    required this.textController,
    required this.focusNode,
    required this.inputScrollController,
    required this.snapPosition,
    required this.fieldMinHeight,
    required this.onDraftChanged,
    required this.onClearMode,
    required this.onRemoveAttachment,
    required this.onRetryAttachment,
    required this.onDeleteAudioDraft,
    this.onTextFieldTap,
  });

  final ConversationComposerState composer;
  final TextEditingController textController;
  final FocusNode focusNode;
  final ScrollController inputScrollController;
  final ComposerAudioSnapPosition snapPosition;
  final double fieldMinHeight;
  final ValueChanged<String> onDraftChanged;
  final VoidCallback onClearMode;
  final ValueChanged<String> onRemoveAttachment;
  final Future<void> Function(String localId) onRetryAttachment;
  final Future<void> Function() onDeleteAudioDraft;
  final VoidCallback? onTextFieldTap;

  bool get _isRecordingPhase {
    final draft = composer.audioDraft;
    if (draft == null) {
      return false;
    }
    return draft.phase == ComposerAudioDraftPhase.requestingPermission ||
        draft.phase == ComposerAudioDraftPhase.recording;
  }

  bool get _isSavedDraftPhase {
    final draft = composer.audioDraft;
    if (draft == null) {
      return false;
    }
    return draft.phase == ComposerAudioDraftPhase.recorded ||
        draft.phase == ComposerAudioDraftPhase.uploading;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ComposerPreviewBar(composer: composer, onClearMode: onClearMode),
        if (composer.attachments.isNotEmpty)
          _ComposerAttachmentPreview(
            attachments: composer.attachments,
            onRemoveAttachment: onRemoveAttachment,
            onRetryAttachment: onRetryAttachment,
          ),
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: fieldMinHeight),
          child: _isRecordingPhase
              ? VoiceDraftPanel(
                  draft: composer.audioDraft!,
                  snapPosition: snapPosition,
                  onDelete: null,
                  showDelete: false,
                )
              : _isSavedDraftPhase
              ? VoiceDraftPanel(
                  draft: composer.audioDraft!,
                  snapPosition: snapPosition,
                  onDelete: composer.hasUploadingAudioDraft
                      ? null
                      : () => unawaited(onDeleteAudioDraft()),
                  showDelete: true,
                )
              : CupertinoScrollbar(
                  controller: inputScrollController,
                  child: CupertinoTextField(
                    controller: textController,
                    focusNode: focusNode,
                    scrollController: inputScrollController,
                    onChanged: onDraftChanged,
                    onTap: onTextFieldTap,
                    placeholder: l10n.message,
                    maxLines: 5,
                    minLines: 1,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: null,
                  ),
                ),
        ),
      ],
    );
  }
}

class _ComposerPreviewBar extends StatelessWidget {
  const _ComposerPreviewBar({
    required this.composer,
    required this.onClearMode,
  });

  final ConversationComposerState composer;
  final VoidCallback onClearMode;

  @override
  Widget build(BuildContext context) {
    final mode = composer.mode;
    return switch (mode) {
      ComposerReplying(:final message) => _PreviewBar(
        title:
            '${AppLocalizations.of(context)!.reply} ${message.sender.name ?? 'User ${message.sender.uid}'}',
        body: _formatMessagePreview(message),
        onClearMode: onClearMode,
      ),
      ComposerEditing(:final message) => _PreviewBar(
        title: AppLocalizations.of(context)!.edit,
        body: _formatMessagePreview(message),
        onClearMode: onClearMode,
      ),
      ComposerIdle() => const SizedBox.shrink(),
    };
  }

  String _formatMessagePreview(ConversationMessage message) {
    return formatMessagePreview(
      message: message.message,
      messageType: message.messageType,
      sticker: message.sticker,
      attachments: message.attachments,
      firstAttachmentKind: message.attachments.isNotEmpty
          ? message.attachments.first.kind
          : null,
      isDeleted: message.isDeleted,
      mentions: message.mentions,
    );
  }
}

class _PreviewBar extends StatelessWidget {
  const _PreviewBar({
    required this.title,
    required this.body,
    required this.onClearMode,
  });

  final String title;
  final String body;
  final VoidCallback onClearMode;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 4),
      decoration: BoxDecoration(
        color: colors.composerReplyPreviewSurface,
        border: Border(
          bottom: BorderSide(color: colors.composerReplyPreviewDivider),
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
                    fontSize: AppFontSizes.meta,
                    color: colors.composerReplyPreviewTitle,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appSecondaryTextStyle(
                    context,
                    fontSize: AppFontSizes.meta,
                  ),
                ),
              ],
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(30, 30),
            onPressed: onClearMode,
            child: Icon(
              CupertinoIcons.xmark_circle_fill,
              size: 18,
              color: colors.inactive,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposerAttachmentPreview extends StatelessWidget {
  const _ComposerAttachmentPreview({
    required this.attachments,
    required this.onRemoveAttachment,
    required this.onRetryAttachment,
  });

  final List<ComposerAttachment> attachments;
  final ValueChanged<String> onRemoveAttachment;
  final Future<void> Function(String localId) onRetryAttachment;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.inputBorder)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final attachment in attachments)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _AttachmentCard(
                  attachment: attachment,
                  onRemove: () => onRemoveAttachment(attachment.localId),
                  onRetry: () =>
                      unawaited(onRetryAttachment(attachment.localId)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentCard extends StatelessWidget {
  const _AttachmentCard({
    required this.attachment,
    required this.onRemove,
    required this.onRetry,
  });

  final ComposerAttachment attachment;
  final VoidCallback onRemove;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final borderColor = CupertinoColors.systemGrey4.resolveFrom(context);
    return Container(
      width: 116,
      height: 116,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withAlpha(26),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _AttachmentPreviewThumb(attachment: attachment),
          Positioned(
            top: 6,
            right: 6,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(28, 28),
              onPressed: onRemove,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: CupertinoColors.black.withAlpha(150),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.xmark,
                  size: 16,
                  color: CupertinoColors.white,
                ),
              ),
            ),
          ),
          if (attachment.isQueued || attachment.isUploading)
            _ProgressOverlay(attachment: attachment)
          else if (attachment.isFailed)
            _ErrorOverlay(attachment: attachment, onRetry: onRetry),
        ],
      ),
    );
  }
}

class _AttachmentPreviewThumb extends StatelessWidget {
  const _AttachmentPreviewThumb({required this.attachment});

  final ComposerAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final background = CupertinoColors.systemGrey4.resolveFrom(context);
    final icon = switch (attachment.kind) {
      ComposerAttachmentKind.video => CupertinoIcons.play_rectangle_fill,
      ComposerAttachmentKind.file => CupertinoIcons.doc_fill,
      _ => CupertinoIcons.photo_fill,
    };

    if (attachment.previewBytes != null) {
      return Image.memory(attachment.previewBytes!, fit: BoxFit.cover);
    }

    return DecoratedBox(
      decoration: BoxDecoration(color: background),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: CupertinoColors.white),
              const SizedBox(height: 8),
              Text(
                attachment.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: appTextStyle(
                  context,
                  fontSize: AppFontSizes.meta,
                  color: CupertinoColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressOverlay extends StatelessWidget {
  const _ProgressOverlay({required this.attachment});

  final ComposerAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final progressValue = attachment.progress > 0 ? attachment.progress : null;
    final progressLabel = '${(attachment.progress * 100).round()}%';
    return Container(
      color: CupertinoColors.black.withAlpha(135),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 54,
            height: 54,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progressValue,
                  strokeWidth: 3,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    CupertinoColors.white,
                  ),
                  backgroundColor: CupertinoColors.white.withAlpha(64),
                ),
                Text(
                  progressValue == null ? '...' : progressLabel,
                  style: appTextStyle(
                    context,
                    fontSize: AppFontSizes.meta,
                    color: CupertinoColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorOverlay extends StatelessWidget {
  const _ErrorOverlay({required this.attachment, required this.onRetry});

  final ComposerAttachment attachment;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xC27F1D1D),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_circle_fill,
            size: 28,
            color: CupertinoColors.white,
          ),
          const SizedBox(height: 8),
          Text(
            attachment.errorMessage ?? 'Upload failed',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: appTextStyle(
              context,
              fontSize: AppFontSizes.meta,
              color: CupertinoColors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: const Size(28, 28),
            color: CupertinoColors.white.withAlpha(36),
            borderRadius: BorderRadius.circular(999),
            onPressed: onRetry,
            child: Text(
              'Retry',
              style: appTextStyle(
                context,
                fontSize: AppFontSizes.meta,
                color: CupertinoColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
