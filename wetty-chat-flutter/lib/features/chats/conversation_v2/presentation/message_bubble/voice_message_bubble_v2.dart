import 'dart:math' as math;

import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/features/chats/conversation_v2/application/voice_message_playback_controller_v2.dart';
import 'package:chahua/features/chats/conversation_v2/application/voice_message_presentation_provider_v2.dart';
import 'package:chahua/features/chats/conversation_v2/data/audio_waveform_cache_service.dart';
import 'package:chahua/features/chats/conversation_v2/domain/conversation_message_v2.dart';
import 'package:chahua/features/chats/models/message_models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'message_bubble_meta_v2.dart';
import 'message_bubble_presentation_v2.dart';
import 'message_render_spec_v2.dart';
import 'message_sender_header_v2.dart';
import 'message_thread_indicator_v2.dart';
import 'voice_message_bubble_fallback_v2.dart';

class VoiceMessageBubbleV2 extends ConsumerStatefulWidget {
  const VoiceMessageBubbleV2({
    super.key,
    required this.attachment,
    required this.isMe,
    required this.renderSpec,
    this.message,
    this.presentation,
  });

  final AttachmentItem attachment;
  final bool isMe;
  final MessageRenderSpecV2 renderSpec;
  final ConversationMessageV2? message;
  final MessageBubblePresentationV2? presentation;

  @override
  ConsumerState<VoiceMessageBubbleV2> createState() =>
      _VoiceMessageBubbleV2State();
}

class _VoiceMessageBubbleV2State extends ConsumerState<VoiceMessageBubbleV2> {
  Duration? _dragPosition;

  @override
  Widget build(BuildContext context) {
    final presentationAsync = ref.watch(
      voiceMessagePresentationV2Provider(widget.attachment),
    );

    return presentationAsync.when(
      loading: () => _UnavailableVoiceMessageBodyV2(
        isMe: widget.isMe,
        renderSpec: widget.renderSpec,
        message: widget.message,
        presentation: widget.presentation,
        statusText: 'Preparing audio...',
        icon: const CupertinoActivityIndicator(),
      ),
      error: (_, _) => _UnavailableVoiceMessageBodyV2(
        isMe: widget.isMe,
        renderSpec: widget.renderSpec,
        message: widget.message,
        presentation: widget.presentation,
        statusText: 'Audio is not playable.',
        icon: const Icon(
          CupertinoIcons.exclamationmark_triangle_fill,
          size: 18,
          color: CupertinoColors.systemYellow,
        ),
      ),
      data: (presentationData) {
        final waveform = presentationData.waveform;
        if (waveform == null) {
          if (presentationData.canPlay) {
            return VoiceMessageBubbleFallbackV2(
              attachment: widget.attachment,
              isMe: widget.isMe,
              renderSpec: widget.renderSpec,
              message: widget.message,
              presentation: widget.presentation,
              resolvedDuration: presentationData.duration,
            );
          }
          return _UnavailableVoiceMessageBodyV2(
            isMe: widget.isMe,
            renderSpec: widget.renderSpec,
            message: widget.message,
            presentation: widget.presentation,
            statusText: 'Audio is not playable.',
            icon: const Icon(
              CupertinoIcons.exclamationmark_triangle_fill,
              size: 18,
              color: CupertinoColors.systemYellow,
            ),
          );
        }
        return _WaveformVoiceMessageBodyV2(
          attachment: widget.attachment,
          isMe: widget.isMe,
          renderSpec: widget.renderSpec,
          message: widget.message,
          presentation: widget.presentation,
          waveform: waveform,
          resolvedDuration: presentationData.duration,
          canPlay: presentationData.canPlay,
          dragPosition: _dragPosition,
          onPreviewSeek: (position) {
            setState(() {
              _dragPosition = position;
            });
          },
          onCommitSeek: () {
            setState(() {
              _dragPosition = null;
            });
          },
        );
      },
    );
  }
}

class _UnavailableVoiceMessageBodyV2 extends StatelessWidget {
  const _UnavailableVoiceMessageBodyV2({
    required this.isMe,
    required this.renderSpec,
    required this.message,
    required this.presentation,
    required this.statusText,
    required this.icon,
  });

  final bool isMe;
  final MessageRenderSpecV2 renderSpec;
  final ConversationMessageV2? message;
  final MessageBubblePresentationV2? presentation;
  final String statusText;
  final Widget icon;

  @override
  Widget build(BuildContext context) {
    final bubbleColor =
        presentation?.bubbleColor ??
        (isMe
            ? context.appColors.chatSentBubble
            : context.appColors.chatReceivedBubble);
    final metaColor =
        presentation?.metaColor ?? context.appColors.textSecondary;

    return Container(
      width: 220,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (renderSpec.showSenderName &&
              message != null &&
              presentation != null)
            Padding(
              padding: const EdgeInsets.only(
                bottom: MessageBubblePresentationV2.senderHeaderBodyGap,
              ),
              child: MessageSenderHeaderV2(
                senderName: presentation!.senderName,
                textColor: presentation!.textColor,
                gender: message!.sender.gender,
              ),
            ),
          Row(
            children: [
              SizedBox(width: 32, height: 32, child: Center(child: icon)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  statusText,
                  style: appSecondaryTextStyle(
                    context,
                    fontSize: AppFontSizes.meta,
                  ).copyWith(color: metaColor),
                ),
              ),
            ],
          ),
          if (message != null && presentation != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Spacer(),
                MessageBubbleMetaV2(
                  message: message!,
                  presentation: presentation!,
                  isMe: isMe,
                ),
              ],
            ),
            if (renderSpec.showThreadIndicator &&
                message!.threadInfo != null &&
                message!.threadInfo!.replyCount > 0) ...[
              const SizedBox(height: 4),
              MessageThreadIndicatorV2(
                threadInfo: message!.threadInfo!,
                isMe: isMe,
                presentation: presentation!,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _WaveformVoiceMessageBodyV2 extends ConsumerWidget {
  const _WaveformVoiceMessageBodyV2({
    required this.attachment,
    required this.isMe,
    required this.renderSpec,
    required this.message,
    required this.presentation,
    required this.waveform,
    required this.resolvedDuration,
    required this.canPlay,
    required this.dragPosition,
    required this.onPreviewSeek,
    required this.onCommitSeek,
  });

  final AttachmentItem attachment;
  final bool isMe;
  final MessageRenderSpecV2 renderSpec;
  final ConversationMessageV2? message;
  final MessageBubblePresentationV2? presentation;
  final AudioWaveformSnapshot waveform;
  final Duration? resolvedDuration;
  final bool canPlay;
  final Duration? dragPosition;
  final ValueChanged<Duration> onPreviewSeek;
  final VoidCallback onCommitSeek;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playbackState = ref.watch(voiceMessagePlaybackControllerV2Provider);
    final controller = ref.read(
      voiceMessagePlaybackControllerV2Provider.notifier,
    );
    final isActive = playbackState.isActive(attachment.id);
    final phase = isActive
        ? playbackState.phase
        : VoiceMessagePlaybackPhaseV2.idle;
    final duration = resolveVoiceMessageDurationV2(
      attachmentDuration: attachment.duration,
      playbackDuration: playbackState.durationFor(attachment.id),
      waveformDuration: waveform.duration,
      resolvedDuration: resolvedDuration,
    );
    final resolvedPosition = switch (phase) {
      VoiceMessagePlaybackPhaseV2.completed => duration,
      _ => dragPosition ?? (isActive ? playbackState.position : Duration.zero),
    };
    final clampedPosition = _clampDuration(
      resolvedPosition,
      Duration.zero,
      duration,
    );
    final progress = _progressFor(clampedPosition, duration);
    final visibleSamples = _visibleSamplesForWaveform(
      waveform.samples,
      AudioWaveformCacheService.targetBarCount,
    );
    final waveformWidth = voiceMessageUniformWaveformWidthV2;
    final bubbleColor =
        presentation?.bubbleColor ??
        (isMe
            ? context.appColors.chatSentBubble
            : context.appColors.chatReceivedBubble);
    final metaColor =
        presentation?.metaColor ?? context.appColors.textSecondary;
    final accent = isMe
        ? CupertinoColors.white
        : CupertinoColors.activeBlue.resolveFrom(context);
    final buttonBackground = isMe
        ? CupertinoColors.white.withAlpha(36)
        : accent.withAlpha(28);
    final inactiveWaveformColor = isMe
        ? CupertinoColors.white.withAlpha(92)
        : accent.withAlpha(72);
    final secondaryText = phase == VoiceMessagePlaybackPhaseV2.error
        ? playbackState.errorMessage ?? 'Audio playback failed'
        : '${_formatDuration(clampedPosition)} / ${_formatDuration(duration)}';
    final statusTextWidth = _measureVoiceMessageTextWidth(
      context,
      secondaryText,
      isError: phase == VoiceMessagePlaybackPhaseV2.error,
      metaColor: metaColor,
    );
    final metaWidth = message != null && presentation != null
        ? presentation!.timeSpacerWidth
        : 0.0;
    final bubbleWidth = _bubbleWidthForVoiceMessage(
      waveformWidth: waveformWidth,
      statusTextWidth: statusTextWidth,
      metaWidth: metaWidth,
      maxBubbleWidth: presentation?.maxBubbleWidth,
    );

    return Container(
      width: bubbleWidth,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (renderSpec.showSenderName &&
              message != null &&
              presentation != null)
            Padding(
              padding: const EdgeInsets.only(
                bottom: MessageBubblePresentationV2.senderHeaderBodyGap,
              ),
              child: MessageSenderHeaderV2(
                senderName: presentation!.senderName,
                textColor: presentation!.textColor,
                gender: message!.sender.gender,
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
                      ? () => controller.togglePlayback(attachment)
                      : null,
                  child: _PlaybackIconV2(phase: phase, iconColor: accent),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: !canPlay
                    ? null
                    : (details) async {
                        final target = _positionFromDx(
                          details.localPosition.dx,
                          waveformWidth,
                          duration,
                        );
                        await controller.playFromPosition(attachment, target);
                      },
                onHorizontalDragStart: !canPlay
                    ? null
                    : (details) {
                        onPreviewSeek(
                          _positionFromDx(
                            details.localPosition.dx,
                            waveformWidth,
                            duration,
                          ),
                        );
                      },
                onHorizontalDragUpdate: !canPlay
                    ? null
                    : (details) {
                        onPreviewSeek(
                          _positionFromDx(
                            details.localPosition.dx,
                            waveformWidth,
                            duration,
                          ),
                        );
                      },
                onHorizontalDragEnd: !canPlay || dragPosition == null
                    ? null
                    : (_) async {
                        final target = dragPosition!;
                        onCommitSeek();
                        await controller.playFromPosition(attachment, target);
                      },
                onHorizontalDragCancel: onCommitSeek,
                child: SizedBox(
                  height: 32,
                  width: waveformWidth,
                  child: CustomPaint(
                    painter: _WaveformPainterV2(
                      samples: visibleSamples,
                      progress: progress,
                      activeColor: accent,
                      inactiveColor: inactiveWaveformColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
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
                        color: phase == VoiceMessagePlaybackPhaseV2.error
                            ? CupertinoColors.systemRed.resolveFrom(context)
                            : metaColor,
                      ),
                ),
              ),
              if (message != null && presentation != null) ...[
                const SizedBox(width: 8),
                MessageBubbleMetaV2(
                  message: message!,
                  presentation: presentation!,
                  isMe: isMe,
                ),
              ],
            ],
          ),
          if (renderSpec.showThreadIndicator &&
              message != null &&
              presentation != null &&
              message!.threadInfo != null &&
              message!.threadInfo!.replyCount > 0) ...[
            const SizedBox(height: 4),
            MessageThreadIndicatorV2(
              threadInfo: message!.threadInfo!,
              isMe: isMe,
              presentation: presentation!,
            ),
          ],
        ],
      ),
    );
  }
}

class _PlaybackIconV2 extends StatelessWidget {
  const _PlaybackIconV2({required this.phase, required this.iconColor});

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

class _WaveformPainterV2 extends CustomPainter {
  const _WaveformPainterV2({
    required this.samples,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

  static const double barWidth = 3;
  static const double gap = 2;

  final List<int> samples;
  final double progress;
  final Color activeColor;
  final Color inactiveColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.isEmpty || size.width <= 0) {
      return;
    }

    final playedCount = (samples.length * progress).round();
    const radius = Radius.circular(barWidth / 2);
    final baseline = size.height / 2;

    for (var index = 0; index < samples.length; index++) {
      final x = index * (barWidth + gap);
      final normalized = (samples[index] / 255).clamp(0.0, 1.0);
      final barHeight = math.max(6.0, size.height * (0.2 + normalized * 0.8));
      final rect = Rect.fromLTWH(
        x,
        baseline - barHeight / 2,
        barWidth,
        barHeight,
      );
      final paint = Paint()
        ..color = index < playedCount ? activeColor : inactiveColor;
      canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainterV2 oldDelegate) {
    return oldDelegate.samples != samples ||
        oldDelegate.progress != progress ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.inactiveColor != inactiveColor;
  }
}

double _progressFor(Duration position, Duration duration) {
  if (duration <= Duration.zero) {
    return 0;
  }
  return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
}

const double _voiceBubbleHorizontalPadding = 24;
const double _voiceWaveformButtonSize = 32;
const double _voiceWaveformGap = 10;
const double _voiceWaveformMaxWidth = 173;

const double voiceMessageUniformWaveformWidthV2 = _voiceWaveformMaxWidth;

List<int> _visibleSamplesForWaveform(List<int> samples, int targetCount) {
  if (samples.isEmpty || targetCount <= 0) {
    return const <int>[];
  }
  if (samples.length == targetCount) {
    return samples;
  }

  return List<int>.generate(targetCount, (index) {
    final start = (index * samples.length / targetCount).floor();
    final end = math.max(
      start + 1,
      ((index + 1) * samples.length / targetCount).ceil(),
    );
    var peak = 0;
    for (var sampleIndex = start; sampleIndex < end; sampleIndex++) {
      peak = math.max(peak, samples[sampleIndex]);
    }
    return peak;
  }, growable: false);
}

double _bubbleWidthForWaveformWidth(double waveformWidth) {
  return _voiceBubbleHorizontalPadding +
      _voiceWaveformButtonSize +
      _voiceWaveformGap +
      waveformWidth;
}

double _minBubbleWidthForMetaRow(double statusTextWidth, double metaWidth) {
  return _voiceBubbleHorizontalPadding + statusTextWidth + metaWidth;
}

double _bubbleWidthForVoiceMessage({
  required double waveformWidth,
  required double statusTextWidth,
  required double metaWidth,
  double? maxBubbleWidth,
}) {
  final computedWidth = math.max(
    _bubbleWidthForWaveformWidth(waveformWidth),
    _minBubbleWidthForMetaRow(statusTextWidth, metaWidth),
  );
  if (maxBubbleWidth == null) {
    return computedWidth;
  }
  return math.min(computedWidth, maxBubbleWidth);
}

double _measureVoiceMessageTextWidth(
  BuildContext context,
  String text, {
  required bool isError,
  required Color metaColor,
}) {
  final style = appSecondaryTextStyle(context, fontSize: AppFontSizes.meta)
      .copyWith(
        color: isError
            ? CupertinoColors.systemRed.resolveFrom(context)
            : metaColor,
      );
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    maxLines: 1,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: double.infinity);
  return painter.width;
}

Duration _positionFromDx(double dx, double width, Duration duration) {
  if (width <= 0 || duration <= Duration.zero) {
    return Duration.zero;
  }
  final ratio = (dx / width).clamp(0.0, 1.0);
  return Duration(milliseconds: (duration.inMilliseconds * ratio).round());
}

Duration resolveVoiceMessageDurationV2({
  Duration? attachmentDuration,
  Duration? playbackDuration,
  Duration? resolvedDuration,
  required Duration? waveformDuration,
}) {
  final candidates = <Duration?>[
    attachmentDuration,
    playbackDuration,
    resolvedDuration,
    waveformDuration,
  ];
  for (final candidate in candidates) {
    if (candidate != null && candidate > Duration.zero) {
      return candidate;
    }
  }
  return attachmentDuration ??
      playbackDuration ??
      resolvedDuration ??
      waveformDuration ??
      Duration.zero;
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
