import 'package:chahua/features/conversation/media/data/audio_waveform_cache_service.dart';
import 'package:chahua/features/conversation/timeline/presentation/voice_message_playback_controller_v2.dart';
import 'package:chahua/features/chats/models/message_models.dart';
import 'package:flutter/cupertino.dart';

import 'voice_utils.dart';
import 'voice_waveform_painter.dart';

class VoiceWaveformView extends StatelessWidget {
  const VoiceWaveformView({
    super.key,
    required this.attachment,
    required this.waveform,
    required this.duration,
    required this.position,
    required this.canPlay,
    required this.phase,
    required this.accentColor,
    required this.buttonBackgroundColor,
    required this.inactiveWaveformColor,
    required this.onTogglePlayback,
    required this.onSeekPreview,
    required this.onSeekCommit,
    required this.onSeekCancel,
    required this.dragPosition,
  });

  final AttachmentItem attachment;
  final AudioWaveformSnapshot waveform;
  final Duration duration;
  final Duration position;
  final bool canPlay;
  final VoiceMessagePlaybackPhaseV2 phase;
  final Color accentColor;
  final Color buttonBackgroundColor;
  final Color inactiveWaveformColor;
  final VoidCallback onTogglePlayback;
  final ValueChanged<Duration> onSeekPreview;
  final ValueChanged<Duration> onSeekCommit;
  final VoidCallback onSeekCancel;
  final Duration? dragPosition;

  @override
  Widget build(BuildContext context) {
    final visibleSamples = visibleSamplesForWaveform(
      waveform.samples,
      AudioWaveformCacheService.targetBarCount,
    );
    final waveformWidth = voiceUniformWaveformWidth;
    final progress = progressFor(position, duration);
    final iconKind = _iconKindFor(phase);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: buttonBackgroundColor,
            shape: BoxShape.circle,
          ),
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size.square(32),
            onPressed: canPlay ? onTogglePlayback : null,
            child: VoicePlaybackIcon(
              phaseKind: iconKind,
              iconColor: accentColor,
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: !canPlay
              ? null
              : (details) {
                  final target = positionFromDx(
                    details.localPosition.dx,
                    waveformWidth,
                    duration,
                  );
                  onSeekCommit(target);
                },
          onHorizontalDragStart: !canPlay
              ? null
              : (details) {
                  onSeekPreview(
                    positionFromDx(
                      details.localPosition.dx,
                      waveformWidth,
                      duration,
                    ),
                  );
                },
          onHorizontalDragUpdate: !canPlay
              ? null
              : (details) {
                  onSeekPreview(
                    positionFromDx(
                      details.localPosition.dx,
                      waveformWidth,
                      duration,
                    ),
                  );
                },
          onHorizontalDragEnd: !canPlay || dragPosition == null
              ? null
              : (_) => onSeekCommit(dragPosition!),
          onHorizontalDragCancel: onSeekCancel,
          child: SizedBox(
            height: 32,
            width: waveformWidth,
            child: CustomPaint(
              painter: VoiceWaveformPainter(
                samples: visibleSamples,
                progress: progress,
                activeColor: accentColor,
                inactiveColor: inactiveWaveformColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

VoicePlaybackIconKind _iconKindFor(VoiceMessagePlaybackPhaseV2 phase) {
  switch (phase) {
    case VoiceMessagePlaybackPhaseV2.loading:
      return VoicePlaybackIconKind.loading;
    case VoiceMessagePlaybackPhaseV2.playing:
      return VoicePlaybackIconKind.playing;
    case VoiceMessagePlaybackPhaseV2.error:
      return VoicePlaybackIconKind.error;
    case VoiceMessagePlaybackPhaseV2.idle:
    case VoiceMessagePlaybackPhaseV2.ready:
    case VoiceMessagePlaybackPhaseV2.paused:
    case VoiceMessagePlaybackPhaseV2.completed:
      return VoicePlaybackIconKind.play;
  }
}
