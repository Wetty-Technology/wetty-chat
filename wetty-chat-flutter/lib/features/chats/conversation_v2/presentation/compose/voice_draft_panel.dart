import 'dart:async';

import 'package:flutter/cupertino.dart';

import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/features/chats/conversation_v2/application/conversation_composer_view_model.dart';
import 'package:chahua/features/chats/conversation_v2/presentation/compose/composer_audio_controls.dart';
import 'package:chahua/l10n/app_localizations.dart';

class VoiceDraftPanel extends StatelessWidget {
  const VoiceDraftPanel({
    super.key,
    required this.draft,
    required this.snapPosition,
    required this.minHeight,
    required this.onDelete,
    required this.showDelete,
  });

  final ComposerAudioDraft draft;
  final ComposerAudioSnapPosition snapPosition;
  final double minHeight;
  final Future<void> Function()? onDelete;
  final bool showDelete;

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final hint = switch (draft.phase) {
      ComposerAudioDraftPhase.requestingPermission =>
        l10n.voiceWaitingForMicrophone,
      ComposerAudioDraftPhase.recording =>
        snapPosition == ComposerAudioSnapPosition.left
            ? l10n.deleteRecording
            : snapPosition == ComposerAudioSnapPosition.top
            ? l10n.sendVoiceMessage
            : l10n.voiceReleaseToSave,
      ComposerAudioDraftPhase.recorded => l10n.voiceMessage,
      ComposerAudioDraftPhase.uploading => l10n.voiceUploadingProgress(
        (draft.progress * 100).round(),
      ),
    };

    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          draft.isRecording
              ? const _RecordingPulseIndicator()
              : Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: colors.composerReplyPreviewSurface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    CupertinoIcons.doc_fill,
                    size: 16,
                    color: CupertinoColors.activeBlue.resolveFrom(context),
                  ),
                ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatDuration(draft.duration),
                  style: appTextStyle(
                    context,
                    fontSize: AppFontSizes.body,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hint,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: appSecondaryTextStyle(
                      context,
                      fontSize: AppFontSizes.meta,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (showDelete) ...[
            const SizedBox(width: 6),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(30, 30),
              onPressed: onDelete == null ? null : () => unawaited(onDelete!()),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: onDelete == null
                      ? CupertinoColors.systemGrey3.resolveFrom(context)
                      : CupertinoColors.systemGrey.resolveFrom(context),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.delete_solid,
                  size: 16,
                  color: CupertinoColors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecordingPulseIndicator extends StatefulWidget {
  const _RecordingPulseIndicator();

  @override
  State<_RecordingPulseIndicator> createState() =>
      _RecordingPulseIndicatorState();
}

class _RecordingPulseIndicatorState extends State<_RecordingPulseIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final red = CupertinoColors.systemRed.resolveFrom(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        final haloScale = 1 + (progress * 0.7);
        final haloOpacity = 0.38 * (1 - progress);
        return SizedBox(
          width: 28,
          height: 28,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.scale(
                  scale: haloScale,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: red.withValues(alpha: haloOpacity),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: red, shape: BoxShape.circle),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
