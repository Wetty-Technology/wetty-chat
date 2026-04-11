import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/style_config.dart';
import '../../application/voice_message_playback_controller.dart';
import '../../data/audio_waveform_cache_service.dart';
import '../../domain/conversation_message.dart';
import '../../../models/message_models.dart';
import 'message_bubble_meta.dart';
import 'message_bubble_presentation.dart';

class VoiceMessageBubble extends ConsumerStatefulWidget {
  const VoiceMessageBubble({
    super.key,
    required this.attachment,
    required this.isMe,
    this.message,
    this.presentation,
  });

  final AttachmentItem attachment;
  final bool isMe;
  final ConversationMessage? message;
  final MessageBubblePresentation? presentation;

  @override
  ConsumerState<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends ConsumerState<VoiceMessageBubble> {
  Duration? _dragPosition;
  Future<AudioWaveformSnapshot?>? _waveformFuture;

  @override
  void initState() {
    super.initState();
    _waveformFuture = _resolveWaveform();
  }

  @override
  void didUpdateWidget(covariant VoiceMessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.attachment.id != widget.attachment.id ||
        oldWidget.attachment.url != widget.attachment.url ||
        oldWidget.attachment.waveformSamples !=
            widget.attachment.waveformSamples) {
      _waveformFuture = _resolveWaveform();
    }
  }

  Future<AudioWaveformSnapshot?> _resolveWaveform() {
    return ref
        .read(audioWaveformCacheServiceProvider)
        .resolveForAttachment(widget.attachment);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AudioWaveformSnapshot?>(
      future: _waveformFuture,
      builder: (context, snapshot) {
        final waveform = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done &&
            waveform == null) {
          return _UnavailableVoiceMessageBody(
            isMe: widget.isMe,
            message: widget.message,
            presentation: widget.presentation,
            statusText: 'Preparing audio...',
            icon: const CupertinoActivityIndicator(),
          );
        }
        if (waveform == null) {
          return _UnavailableVoiceMessageBody(
            isMe: widget.isMe,
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
        return _WaveformVoiceMessageBody(
          attachment: widget.attachment,
          isMe: widget.isMe,
          message: widget.message,
          presentation: widget.presentation,
          waveform: waveform,
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

class _UnavailableVoiceMessageBody extends StatelessWidget {
  const _UnavailableVoiceMessageBody({
    required this.isMe,
    required this.message,
    required this.presentation,
    required this.statusText,
    required this.icon,
  });

  final bool isMe;
  final ConversationMessage? message;
  final MessageBubblePresentation? presentation;
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
                MessageBubbleMeta(
                  message: message!,
                  presentation: presentation!,
                  isMe: isMe,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WaveformVoiceMessageBody extends ConsumerWidget {
  const _WaveformVoiceMessageBody({
    required this.attachment,
    required this.isMe,
    required this.message,
    required this.presentation,
    required this.waveform,
    required this.dragPosition,
    required this.onPreviewSeek,
    required this.onCommitSeek,
  });

  final AttachmentItem attachment;
  final bool isMe;
  final ConversationMessage? message;
  final MessageBubblePresentation? presentation;
  final AudioWaveformSnapshot waveform;
  final Duration? dragPosition;
  final ValueChanged<Duration> onPreviewSeek;
  final VoidCallback onCommitSeek;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playbackState = ref.watch(voiceMessagePlaybackControllerProvider);
    final controller = ref.read(
      voiceMessagePlaybackControllerProvider.notifier,
    );
    final isActive = playbackState.isActive(attachment.id);
    final phase = isActive
        ? playbackState.phase
        : VoiceMessagePlaybackPhase.idle;
    final duration = attachment.duration ?? waveform.duration;
    final resolvedPosition = switch (phase) {
      VoiceMessagePlaybackPhase.completed => duration,
      _ => dragPosition ?? (isActive ? playbackState.position : Duration.zero),
    };
    final clampedPosition = _clampDuration(
      resolvedPosition,
      Duration.zero,
      duration,
    );
    final progress = _progressFor(clampedPosition, duration);
    final visibleBarCount = _visibleBarCountForDuration(duration);
    final visibleSamples = _visibleSamplesForWaveform(
      waveform.samples,
      visibleBarCount,
    );
    final waveformWidth = _waveformWidthForBarCount(visibleBarCount);
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
    final canPlay = attachment.url.isNotEmpty;
    final secondaryText = phase == VoiceMessagePlaybackPhase.error
        ? playbackState.errorMessage ?? 'Audio playback failed'
        : '${_formatDuration(clampedPosition)} / ${_formatDuration(duration)}';
    final statusTextWidth = _measureVoiceMessageTextWidth(
      context,
      secondaryText,
      isError: phase == VoiceMessagePlaybackPhase.error,
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
                  child: _PlaybackIcon(phase: phase, iconColor: accent),
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
                    painter: _WaveformPainter(
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
                        color: phase == VoiceMessagePlaybackPhase.error
                            ? CupertinoColors.systemRed.resolveFrom(context)
                            : metaColor,
                      ),
                ),
              ),
              if (message != null && presentation != null) ...[
                const SizedBox(width: 8),
                MessageBubbleMeta(
                  message: message!,
                  presentation: presentation!,
                  isMe: isMe,
                ),
              ],
            ],
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

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({
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
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
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
const double _voiceWaveformMinWidth = 88;
const double _voiceWaveformMaxWidth = 173;
const int _voiceWaveformMinBars = 16;
const int _voiceWaveformBarsPerSecond = 4;

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

int _visibleBarCountForDuration(Duration duration) {
  final target = duration.inSeconds * _voiceWaveformBarsPerSecond;
  return target
      .clamp(_voiceWaveformMinBars, AudioWaveformCacheService.targetBarCount)
      .toInt();
}

double _waveformWidthForBarCount(int barCount) {
  final rawWidth =
      (barCount * _WaveformPainter.barWidth) +
      ((barCount - 1) * _WaveformPainter.gap);
  return rawWidth
      .clamp(_voiceWaveformMinWidth, _voiceWaveformMaxWidth)
      .toDouble();
}

@visibleForTesting
double voiceMessageWaveformWidthForBarCount(int barCount) {
  return _waveformWidthForBarCount(barCount);
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

@visibleForTesting
double voiceMessageBubbleWidthFor({
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

double _bubbleWidthForVoiceMessage({
  required double waveformWidth,
  required double statusTextWidth,
  required double metaWidth,
  double? maxBubbleWidth,
}) => voiceMessageBubbleWidthFor(
  waveformWidth: waveformWidth,
  statusTextWidth: statusTextWidth,
  metaWidth: metaWidth,
  maxBubbleWidth: maxBubbleWidth,
);

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
