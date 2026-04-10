import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../app/theme/style_config.dart';
import '../../../../../l10n/app_localizations.dart';
import '../../application/voice_message_playback_controller.dart';
import '../../data/audio_waveform_cache_service.dart';
import '../../../models/message_models.dart';
import 'voice_message_bubble_fallback.dart';

class VoiceMessageBubble extends ConsumerStatefulWidget {
  const VoiceMessageBubble({
    super.key,
    required this.attachment,
    required this.isMe,
  });

  final AttachmentItem attachment;
  final bool isMe;

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
        if (waveform == null) {
          return VoiceMessageBubbleFallback(
            attachment: widget.attachment,
            isMe: widget.isMe,
          );
        }
        return _WaveformVoiceMessageBody(
          attachment: widget.attachment,
          isMe: widget.isMe,
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

class _WaveformVoiceMessageBody extends ConsumerWidget {
  const _WaveformVoiceMessageBody({
    required this.attachment,
    required this.isMe,
    required this.waveform,
    required this.dragPosition,
    required this.onPreviewSeek,
    required this.onCommitSeek,
  });

  final AttachmentItem attachment;
  final bool isMe;
  final AudioWaveformSnapshot waveform;
  final Duration? dragPosition;
  final ValueChanged<Duration> onPreviewSeek;
  final VoidCallback onCommitSeek;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final playbackState = ref.watch(voiceMessagePlaybackControllerProvider);
    final controller = ref.read(
      voiceMessagePlaybackControllerProvider.notifier,
    );
    final isActive = playbackState.isActive(attachment.id);
    final phase = isActive
        ? playbackState.phase
        : VoiceMessagePlaybackPhase.idle;
    final duration = attachment.duration ?? waveform.duration;
    final position =
        dragPosition ?? (isActive ? playbackState.position : Duration.zero);
    final clampedPosition = _clampDuration(position, Duration.zero, duration);
    final progress = _progressFor(clampedPosition, duration);
    final background = isMe
        ? context.appColors.chatAttachmentChipSent
        : context.appColors.chatAttachmentChipReceived;
    final accent = CupertinoColors.activeBlue.resolveFrom(context);
    final canPlay = attachment.url.isNotEmpty;
    final secondaryText = phase == VoiceMessagePlaybackPhase.error
        ? playbackState.errorMessage ?? 'Audio playback failed'
        : isActive && phase == VoiceMessagePlaybackPhase.playing
        ? '${_formatDuration(clampedPosition)} / ${_formatDuration(duration)}'
        : _formatDuration(duration);

    return Container(
      width: 240,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
                  ? () => controller.togglePlayback(attachment)
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
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: !canPlay
                          ? null
                          : (details) async {
                              final target = _positionFromDx(
                                details.localPosition.dx,
                                width,
                                duration,
                              );
                              await controller.playFromPosition(
                                attachment,
                                target,
                              );
                            },
                      onHorizontalDragStart: !canPlay
                          ? null
                          : (details) {
                              onPreviewSeek(
                                _positionFromDx(
                                  details.localPosition.dx,
                                  width,
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
                                  width,
                                  duration,
                                ),
                              );
                            },
                      onHorizontalDragEnd: !canPlay || dragPosition == null
                          ? null
                          : (_) async {
                              final target = dragPosition!;
                              onCommitSeek();
                              await controller.playFromPosition(
                                attachment,
                                target,
                              );
                            },
                      onHorizontalDragCancel: onCommitSeek,
                      child: SizedBox(
                        height: 32,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: _WaveformPainter(
                            samples: waveform.samples,
                            progress: progress,
                            activeColor: accent,
                            inactiveColor: accent.withAlpha(72),
                          ),
                        ),
                      ),
                    );
                  },
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
                                  ? CupertinoColors.systemRed.resolveFrom(
                                      context,
                                    )
                                  : context.appColors.textSecondary,
                            ),
                      ),
                    ),
                    if (phase == VoiceMessagePlaybackPhase.playing)
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

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({
    required this.samples,
    required this.progress,
    required this.activeColor,
    required this.inactiveColor,
  });

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
    const gap = 2.0;
    final barWidth = math.max(
      2.0,
      (size.width - gap * (samples.length - 1)) / samples.length,
    );
    final radius = Radius.circular(barWidth / 2);
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
