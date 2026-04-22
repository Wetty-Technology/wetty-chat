import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/features/conversation/timeline/presentation/voice_message_playback_controller_v2.dart';
import 'package:chahua/features/conversation/shared/domain/conversation_message_v2.dart';
import 'package:chahua/features/chats/models/message_models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'message_bubble_meta_v2.dart';
import 'message_bubble_presentation_v2.dart';
import 'message_render_spec_v2.dart';
import 'message_sender_header_v2.dart';
import 'message_thread_indicator_v2.dart';
import 'voice_message_bubble_v2.dart';

class VoiceMessageBubbleFallbackV2 extends ConsumerStatefulWidget {
  const VoiceMessageBubbleFallbackV2({
    super.key,
    required this.attachment,
    required this.isMe,
    required this.renderSpec,
    this.resolvedDuration,
    this.message,
    this.presentation,
  });

  final AttachmentItem attachment;
  final bool isMe;
  final MessageRenderSpecV2 renderSpec;
  final Duration? resolvedDuration;
  final ConversationMessageV2? message;
  final MessageBubblePresentationV2? presentation;

  @override
  ConsumerState<VoiceMessageBubbleFallbackV2> createState() =>
      _VoiceMessageBubbleFallbackV2State();
}

class _VoiceMessageBubbleFallbackV2State
    extends ConsumerState<VoiceMessageBubbleFallbackV2> {
  Duration? _dragPosition;

  @override
  Widget build(BuildContext context) {
    final playbackState = ref.watch(voiceMessagePlaybackControllerV2Provider);
    final controller = ref.read(
      voiceMessagePlaybackControllerV2Provider.notifier,
    );
    final isActive = playbackState.isActive(widget.attachment.id);
    final phase = isActive
        ? playbackState.phase
        : VoiceMessagePlaybackPhaseV2.idle;
    final duration =
        widget.attachment.duration ??
        widget.resolvedDuration ??
        playbackState.durationFor(widget.attachment.id);
    final livePosition = switch (phase) {
      VoiceMessagePlaybackPhaseV2.completed => duration ?? Duration.zero,
      _ => isActive ? playbackState.position : Duration.zero,
    };
    final sliderPosition = _dragPosition ?? livePosition;
    final clampedSliderPosition = duration == null
        ? sliderPosition
        : _clampDuration(sliderPosition, Duration.zero, duration);
    final waveformWidth = voiceMessageUniformWaveformWidthV2;
    final bubbleWidth = _fallbackBubbleWidthForWaveformWidth(waveformWidth);
    final bubbleColor =
        widget.presentation?.bubbleColor ??
        (widget.isMe
            ? context.appColors.chatSentBubble
            : context.appColors.chatReceivedBubble);
    final metaColor =
        widget.presentation?.metaColor ?? context.appColors.textSecondary;
    final accent = widget.isMe
        ? CupertinoColors.white
        : CupertinoColors.activeBlue.resolveFrom(context);
    final buttonBackground = widget.isMe
        ? CupertinoColors.white.withAlpha(36)
        : accent.withAlpha(28);
    final canPlay = widget.attachment.url.isNotEmpty;
    final secondaryText = isActive && phase == VoiceMessagePlaybackPhaseV2.error
        ? playbackState.errorMessage ?? 'Audio playback failed'
        : '${_formatDuration(clampedSliderPosition)} / ${_formatDuration(duration)}';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: canPlay
          ? () => controller.togglePlayback(widget.attachment)
          : null,
      child: Container(
        width: bubbleWidth,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.renderSpec.showSenderName &&
                widget.message != null &&
                widget.presentation != null)
              Padding(
                padding: const EdgeInsets.only(
                  bottom: MessageBubblePresentationV2.senderHeaderBodyGap,
                ),
                child: MessageSenderHeaderV2(
                  senderName: widget.presentation!.senderName,
                  textColor: widget.presentation!.textColor,
                  gender: widget.message!.sender.gender,
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: buttonBackground,
                    shape: BoxShape.circle,
                  ),
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size.square(32),
                    onPressed: canPlay
                        ? () => controller.togglePlayback(widget.attachment)
                        : null,
                    child: _FallbackPlaybackIconV2(
                      phase: phase,
                      iconColor: accent,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: waveformWidth,
                  child: CupertinoSlider(
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
                ),
              ],
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
                                  phase == VoiceMessagePlaybackPhaseV2.error
                              ? CupertinoColors.systemRed.resolveFrom(context)
                              : metaColor,
                        ),
                  ),
                ),
                if (widget.message != null && widget.presentation != null) ...[
                  const SizedBox(width: 8),
                  MessageBubbleMetaV2(
                    message: widget.message!,
                    presentation: widget.presentation!,
                    isMe: widget.isMe,
                  ),
                ],
              ],
            ),
            if (widget.renderSpec.showThreadIndicator &&
                widget.message != null &&
                widget.presentation != null &&
                widget.message!.threadInfo != null &&
                widget.message!.threadInfo!.replyCount > 0) ...[
              const SizedBox(height: 4),
              MessageThreadIndicatorV2(
                threadInfo: widget.message!.threadInfo!,
                isMe: widget.isMe,
                presentation: widget.presentation!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FallbackPlaybackIconV2 extends StatelessWidget {
  const _FallbackPlaybackIconV2({required this.phase, required this.iconColor});

  final VoiceMessagePlaybackPhaseV2 phase;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    switch (phase) {
      case VoiceMessagePlaybackPhaseV2.loading:
        return CupertinoActivityIndicator(color: iconColor);
      case VoiceMessagePlaybackPhaseV2.playing:
        return Icon(CupertinoIcons.pause_fill, size: 18, color: iconColor);
      case VoiceMessagePlaybackPhaseV2.error:
        return Icon(
          CupertinoIcons.exclamationmark_triangle_fill,
          size: 18,
          color: CupertinoColors.systemRed.resolveFrom(context),
        );
      case VoiceMessagePlaybackPhaseV2.idle:
      case VoiceMessagePlaybackPhaseV2.ready:
      case VoiceMessagePlaybackPhaseV2.paused:
      case VoiceMessagePlaybackPhaseV2.completed:
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

double _fallbackBubbleWidthForWaveformWidth(double waveformWidth) {
  return 24 + 32 + 10 + waveformWidth;
}
