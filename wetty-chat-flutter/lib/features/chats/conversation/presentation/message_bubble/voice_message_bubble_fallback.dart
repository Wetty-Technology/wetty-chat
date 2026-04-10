import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/style_config.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../application/voice_message_playback_controller.dart';
import '../../../models/message_models.dart';

class VoiceMessageBubbleFallback extends ConsumerStatefulWidget {
  const VoiceMessageBubbleFallback({
    super.key,
    required this.attachment,
    required this.isMe,
  });

  final AttachmentItem attachment;
  final bool isMe;

  @override
  ConsumerState<VoiceMessageBubbleFallback> createState() =>
      _VoiceMessageBubbleFallbackState();
}

class _VoiceMessageBubbleFallbackState
    extends ConsumerState<VoiceMessageBubbleFallback> {
  Duration? _dragPosition;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final playbackState = ref.watch(voiceMessagePlaybackControllerProvider);
    final controller = ref.read(
      voiceMessagePlaybackControllerProvider.notifier,
    );
    final isActive = playbackState.isActive(widget.attachment.id);
    final phase = isActive
        ? playbackState.phase
        : VoiceMessagePlaybackPhase.idle;
    final duration =
        widget.attachment.duration ??
        playbackState.durationFor(widget.attachment.id);
    final livePosition = isActive ? playbackState.position : Duration.zero;
    final sliderPosition = _dragPosition ?? livePosition;
    final clampedSliderPosition = duration == null
        ? sliderPosition
        : _clampDuration(sliderPosition, Duration.zero, duration);
    final background = widget.isMe
        ? context.appColors.chatAttachmentChipSent
        : context.appColors.chatAttachmentChipReceived;
    final accent = CupertinoColors.activeBlue.resolveFrom(context);
    final canPlay = widget.attachment.url.isNotEmpty;
    final secondaryText = isActive && phase == VoiceMessagePlaybackPhase.error
        ? playbackState.errorMessage ?? 'Audio playback failed'
        : '${_formatDuration(clampedSliderPosition)} / ${_formatDuration(duration)}';

    return Container(
      width: 240,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent.withAlpha(28),
              shape: BoxShape.circle,
            ),
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size.square(32),
              onPressed: canPlay
                  ? () => controller.togglePlayback(widget.attachment)
                  : null,
              child: _PlaybackIcon(phase: phase, iconColor: accent),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.voiceMessage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appTextStyle(
                    context,
                    fontSize: AppFontSizes.body,
                    fontWeight: FontWeight.w600,
                    color: context.appColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                CupertinoSlider(
                  value: _sliderValue(clampedSliderPosition, duration),
                  min: 0,
                  max: _sliderMax(duration),
                  activeColor: accent,
                  onChanged: duration == null || !isActive
                      ? null
                      : (value) {
                          setState(() {
                            _dragPosition = Duration(
                              milliseconds: value.round(),
                            );
                          });
                        },
                  onChangeEnd: duration == null || !isActive
                      ? null
                      : (value) async {
                          final nextPosition = Duration(
                            milliseconds: value.round(),
                          );
                          setState(() {
                            _dragPosition = null;
                          });
                          await controller.seekToAttachment(
                            widget.attachment,
                            nextPosition,
                          );
                        },
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        secondaryText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            appSecondaryTextStyle(
                              context,
                              fontSize: AppFontSizes.meta,
                            ).copyWith(
                              color:
                                  isActive &&
                                      phase == VoiceMessagePlaybackPhase.error
                                  ? CupertinoColors.systemRed.resolveFrom(
                                      context,
                                    )
                                  : context.appColors.textSecondary,
                            ),
                      ),
                    ),
                    if (isActive && phase == VoiceMessagePlaybackPhase.playing)
                      Text(
                        'Playing',
                        style: appSecondaryTextStyle(
                          context,
                          fontSize: AppFontSizes.meta,
                        ).copyWith(color: accent),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaybackIcon extends StatelessWidget {
  const _PlaybackIcon({required this.phase, required this.iconColor});

  final VoiceMessagePlaybackPhase phase;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    switch (phase) {
      case VoiceMessagePlaybackPhase.loading:
        return CupertinoActivityIndicator(color: iconColor);
      case VoiceMessagePlaybackPhase.playing:
        return Icon(CupertinoIcons.pause_fill, size: 18, color: iconColor);
      case VoiceMessagePlaybackPhase.error:
        return Icon(
          CupertinoIcons.exclamationmark_triangle_fill,
          size: 18,
          color: CupertinoColors.systemRed.resolveFrom(context),
        );
      case VoiceMessagePlaybackPhase.idle:
      case VoiceMessagePlaybackPhase.ready:
      case VoiceMessagePlaybackPhase.paused:
      case VoiceMessagePlaybackPhase.completed:
        return Icon(CupertinoIcons.play_fill, size: 18, color: iconColor);
    }
  }
}

double _sliderValue(Duration position, Duration? duration) {
  if (duration == null || duration <= Duration.zero) {
    return 0;
  }
  return _clampDuration(
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

String _formatDuration(Duration? duration) {
  if (duration == null) {
    return '--:--';
  }
  final totalSeconds = duration.inSeconds;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

Duration _clampDuration(Duration value, Duration min, Duration max) {
  if (value < min) {
    return min;
  }
  if (value > max) {
    return max;
  }
  return value;
}
