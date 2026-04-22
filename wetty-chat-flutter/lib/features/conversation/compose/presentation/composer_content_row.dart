import 'dart:async';

import 'package:flutter/cupertino.dart';

import 'package:chahua/features/conversation/compose/presentation/conversation_composer_view_model.dart';
import 'package:chahua/features/conversation/compose/presentation/composer_audio_controls.dart';
import 'package:chahua/features/conversation/compose/presentation/voice_draft_panel.dart';
import 'package:chahua/l10n/app_localizations.dart';

class ComposerContentRow extends StatelessWidget {
  const ComposerContentRow({
    super.key,
    required this.composer,
    required this.textController,
    required this.focusNode,
    required this.inputScrollController,
    required this.snapPosition,
    required this.fieldMinHeight,
    required this.onDraftChanged,
    required this.onSend,
    required this.onDeleteAudioDraft,
    this.onToggleStickerPicker,
    this.isStickerPickerOpen = false,
    this.onTextFieldTap,
  });

  final ConversationComposerState composer;
  final TextEditingController textController;
  final FocusNode focusNode;
  final ScrollController inputScrollController;
  final ComposerAudioSnapPosition snapPosition;
  final double fieldMinHeight;
  final ValueChanged<String> onDraftChanged;
  final Future<void> Function() onSend;
  final Future<void> Function() onDeleteAudioDraft;
  final VoidCallback? onToggleStickerPicker;
  final bool isStickerPickerOpen;
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

  bool get _showStickerButton =>
      composer.audioDraft == null && onToggleStickerPicker != null;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: fieldMinHeight),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: _isRecordingPhase
                ? VoiceDraftPanel(
                    draft: composer.audioDraft!,
                    snapPosition: snapPosition,
                    minHeight: fieldMinHeight,
                    onDelete: null,
                    showDelete: false,
                  )
                : _isSavedDraftPhase
                ? VoiceDraftPanel(
                    draft: composer.audioDraft!,
                    snapPosition: snapPosition,
                    minHeight: fieldMinHeight,
                    onDelete: composer.hasUploadingAudioDraft
                        ? null
                        : onDeleteAudioDraft,
                    showDelete: true,
                  )
                : CupertinoScrollbar(
                    controller: inputScrollController,
                    child: CupertinoTextField(
                      controller: textController,
                      focusNode: focusNode,
                      scrollController: inputScrollController,
                      onChanged: onDraftChanged,
                      onEditingComplete: () => unawaited(onSend()),
                      onTap: onTextFieldTap,
                      textInputAction: TextInputAction.send,
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
          if (_showStickerButton)
            SizedBox(
              width: 32,
              height: 36,
              child: CupertinoButton(
                padding: const EdgeInsets.only(right: 4),
                minimumSize: const Size(32, 36),
                onPressed: onToggleStickerPicker,
                child: Icon(
                  CupertinoIcons.smiley,
                  color: isStickerPickerOpen
                      ? CupertinoColors.activeBlue.resolveFrom(context)
                      : CupertinoColors.systemGrey.resolveFrom(context),
                  size: 24,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
