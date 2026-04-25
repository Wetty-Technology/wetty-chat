import 'package:chahua/features/conversation/timeline/presentation/voice_message_playback_controller_v2.dart';
import 'package:chahua/features/shared/model/message/message.dart';
import 'package:flutter/cupertino.dart';

import 'voice_utils.dart';
import 'voice_waveform_painter.dart';

class VoiceSliderView extends StatelessWidget {
  const VoiceSliderView({
    super.key,
    required this.attachment,
    required this.duration,
    required this.position,
    required this.canPlay,
    required this.isActive,
    required this.phase,
    required this.accentColor,
    required this.buttonBackgroundColor,
    required this.onTogglePlayback,
    required this.onSeekPreview,
    required this.onSeekCommit,
  });

  final AttachmentItem attachment;
  final Duration? duration;
  final Duration position;
  final bool canPlay;
  final bool isActive;
  final VoiceMessagePlaybackPhaseV2 phase;
  final Color accentColor;
  final Color buttonBackgroundColor;
  final VoidCallback onTogglePlayback;
  final ValueChanged<Duration> onSeekPreview;
  final ValueChanged<Duration> onSeekCommit;

  @override
  Widget build(BuildContext context) {
    final iconKind = _iconKindFor(phase);
    final waveformWidth = voiceUniformWaveformWidth;

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
        SizedBox(
          width: waveformWidth,
          child: CupertinoSlider(
            value: _sliderValue(position, duration),
            min: 0,
            max: _sliderMax(duration),
            activeColor: accentColor,
            onChanged: duration == null || !isActive
                ? null
                : (value) =>
                      onSeekPreview(Duration(milliseconds: value.round())),
            onChangeEnd: duration == null || !isActive
                ? null
                : (value) =>
                      onSeekCommit(Duration(milliseconds: value.round())),
          ),
        ),
      ],
    );
  }
}

double _sliderValue(Duration position, Duration? duration) {
  if (duration == null || duration <= Duration.zero) {
    return 0;
  }
  return clampDuration(
    position,
    Duration.zero,
    duration,
  ).inMilliseconds.toDouble();
}

double _sliderMax(Duration? duration) {
  if (duration == null || duration <= Duration.zero) {
    return 1;
  }
  return duration.inMilliseconds.toDouble();
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
