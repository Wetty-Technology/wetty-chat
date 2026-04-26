import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/features/audio/application/audio_waveform_cache_service.dart';
import 'package:chahua/features/shared/model/message/message.dart';
import 'package:chahua/features/conversation/shared/presentation/conversation_presentation_scope.dart';
import 'package:chahua/features/conversation/timeline/presentation/voice_message_playback_controller_v2.dart';
import 'package:chahua/features/conversation/timeline/presentation/voice_message_presentation_provider_v2.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/bubble_theme_v2.dart';
import 'parts/meta_footer.dart';
import 'parts/reactions.dart';
import 'parts/reply_quote.dart';
import 'parts/sender_header.dart';
import 'parts/thread_indicator.dart';
import 'voice/voice_slider_view.dart';
import 'voice/voice_unavailable_view.dart';
import 'voice/voice_utils.dart';
import 'voice/voice_waveform_view.dart';

class VoiceBubbleV2 extends ConsumerStatefulWidget {
  const VoiceBubbleV2({
    super.key,
    required this.message,
    required this.showSenderName,
    this.onTapReply,
    this.onOpenThread,
    this.onToggleReaction,
  });

  final ConversationMessageV2 message;
  final bool showSenderName;
  final VoidCallback? onTapReply;
  final VoidCallback? onOpenThread;
  final ValueChanged<String>? onToggleReaction;

  @override
  ConsumerState<VoiceBubbleV2> createState() => _VoiceBubbleV2State();
}

class _VoiceBubbleV2State extends ConsumerState<VoiceBubbleV2> {
  Duration? _dragPosition;

  AttachmentItem? get _audioAttachment => switch (widget.message.content) {
    AudioMessageContent(:final audio) => audio,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final attachment = _audioAttachment;
    if (attachment == null) {
      return const SizedBox.shrink();
    }
    final theme = BubbleThemeV2.of(context);
    final presentationAsync = ref.watch(
      voiceMessagePresentationV2Provider(attachment),
    );

    return presentationAsync.when(
      loading: () => _buildUnavailable(
        theme: theme,
        attachment: attachment,
        statusText: 'Preparing audio...',
        icon: const CupertinoActivityIndicator(),
      ),
      error: (_, _) => _buildUnavailable(
        theme: theme,
        attachment: attachment,
        statusText: 'Audio is not playable.',
        icon: const Icon(
          CupertinoIcons.exclamationmark_triangle_fill,
          size: 18,
          color: CupertinoColors.systemYellow,
        ),
      ),
      data: (data) {
        final waveform = data.waveform;
        if (waveform == null) {
          if (data.canPlay) {
            return _buildSlider(
              theme: theme,
              attachment: attachment,
              resolvedDuration: data.duration,
            );
          }
          return _buildUnavailable(
            theme: theme,
            attachment: attachment,
            statusText: 'Audio is not playable.',
            icon: const Icon(
              CupertinoIcons.exclamationmark_triangle_fill,
              size: 18,
              color: CupertinoColors.systemYellow,
            ),
          );
        }
        return _buildWaveform(
          theme: theme,
          attachment: attachment,
          waveform: waveform,
          resolvedDuration: data.duration,
          canPlay: data.canPlay,
        );
      },
    );
  }

  Widget _buildUnavailable({
    required BubbleThemeV2 theme,
    required AttachmentItem attachment,
    required String statusText,
    required Widget icon,
  }) {
    return _scaffold(
      theme: theme,
      attachment: attachment,
      width: 220,
      body: VoiceUnavailableView(
        statusText: statusText,
        icon: icon,
        metaColor: theme.metaColor,
      ),
      statusRow: null,
    );
  }

  Widget _buildWaveform({
    required BubbleThemeV2 theme,
    required AttachmentItem attachment,
    required AudioWaveformSnapshot waveform,
    required Duration? resolvedDuration,
    required bool canPlay,
  }) {
    final playbackState = ref.watch(voiceMessagePlaybackControllerV2Provider);
    final controller = ref.read(
      voiceMessagePlaybackControllerV2Provider.notifier,
    );
    final isActive = playbackState.isActive(attachment.id);
    final phase = isActive
        ? playbackState.phase
        : VoiceMessagePlaybackPhaseV2.idle;
    final duration = resolveVoiceDuration(
      attachmentDuration: attachment.duration,
      playbackDuration: playbackState.durationFor(attachment.id),
      waveformDuration: waveform.duration,
      resolvedDuration: resolvedDuration,
    );
    final resolvedPosition = switch (phase) {
      VoiceMessagePlaybackPhaseV2.completed => duration,
      _ => _dragPosition ?? (isActive ? playbackState.position : Duration.zero),
    };
    final clampedPosition = clampDuration(
      resolvedPosition,
      Duration.zero,
      duration,
    );
    final waveformWidth = voiceUniformWaveformWidth;
    final accent = _accentColor(context, theme);
    final secondaryText = phase == VoiceMessagePlaybackPhaseV2.error
        ? playbackState.errorMessage ?? 'Audio playback failed'
        : '${formatVoiceDuration(clampedPosition)} / ${formatVoiceDuration(duration)}';
    final statusTextWidth = _measureStatusTextWidth(
      context,
      theme,
      secondaryText,
      isError: phase == VoiceMessagePlaybackPhaseV2.error,
    );
    final bubbleWidth = voiceBubbleWidth(
      waveformWidth: waveformWidth,
      statusTextWidth: statusTextWidth,
      metaWidth: theme.timeSpacerWidth,
      maxBubbleWidth: theme.maxBubbleWidth,
    );
    final effectiveCanPlay = canPlay && theme.isInteractive;

    return _scaffold(
      theme: theme,
      attachment: attachment,
      width: bubbleWidth,
      body: VoiceWaveformView(
        attachment: attachment,
        waveform: waveform,
        duration: duration,
        position: clampedPosition,
        canPlay: effectiveCanPlay,
        phase: phase,
        accentColor: accent,
        buttonBackgroundColor: _buttonBackground(context, theme, accent),
        inactiveWaveformColor: _inactiveWaveformColor(theme, accent),
        onTogglePlayback: () => controller.togglePlayback(attachment),
        onSeekPreview: (position) => setState(() => _dragPosition = position),
        onSeekCommit: (position) async {
          setState(() => _dragPosition = null);
          await controller.playFromPosition(attachment, position);
        },
        onSeekCancel: () => setState(() => _dragPosition = null),
        dragPosition: _dragPosition,
      ),
      statusRow: _statusRow(
        theme: theme,
        text: secondaryText,
        isError: phase == VoiceMessagePlaybackPhaseV2.error,
      ),
    );
  }

  Widget _buildSlider({
    required BubbleThemeV2 theme,
    required AttachmentItem attachment,
    required Duration? resolvedDuration,
  }) {
    final playbackState = ref.watch(voiceMessagePlaybackControllerV2Provider);
    final controller = ref.read(
      voiceMessagePlaybackControllerV2Provider.notifier,
    );
    final isActive = playbackState.isActive(attachment.id);
    final phase = isActive
        ? playbackState.phase
        : VoiceMessagePlaybackPhaseV2.idle;
    final duration =
        attachment.duration ??
        resolvedDuration ??
        playbackState.durationFor(attachment.id);
    final livePosition = switch (phase) {
      VoiceMessagePlaybackPhaseV2.completed => duration ?? Duration.zero,
      _ => isActive ? playbackState.position : Duration.zero,
    };
    final sliderPosition = _dragPosition ?? livePosition;
    final clampedPosition = duration == null
        ? sliderPosition
        : clampDuration(sliderPosition, Duration.zero, duration);
    final waveformWidth = voiceUniformWaveformWidth;
    final canPlay = attachment.url.isNotEmpty && theme.isInteractive;
    final accent = _accentColor(context, theme);
    final bubbleWidth = voiceBubbleWidthForWaveformWidth(waveformWidth);
    final secondaryText = isActive && phase == VoiceMessagePlaybackPhaseV2.error
        ? playbackState.errorMessage ?? 'Audio playback failed'
        : '${formatVoiceDuration(clampedPosition)} / ${formatVoiceDuration(duration)}';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: canPlay ? () => controller.togglePlayback(attachment) : null,
      child: _scaffold(
        theme: theme,
        attachment: attachment,
        width: bubbleWidth,
        body: VoiceSliderView(
          attachment: attachment,
          duration: duration,
          position: clampedPosition,
          canPlay: canPlay,
          isActive: isActive,
          phase: phase,
          accentColor: accent,
          buttonBackgroundColor: _buttonBackground(context, theme, accent),
          onTogglePlayback: () => controller.togglePlayback(attachment),
          onSeekPreview: (position) => setState(() => _dragPosition = position),
          onSeekCommit: (position) async {
            setState(() => _dragPosition = null);
            await controller.seekToAttachment(attachment, position);
          },
        ),
        statusRow: _statusRow(
          theme: theme,
          text: secondaryText,
          isError: isActive && phase == VoiceMessagePlaybackPhaseV2.error,
        ),
      ),
    );
  }

  Widget _scaffold({
    required BubbleThemeV2 theme,
    required AttachmentItem attachment,
    required double width,
    required Widget body,
    required Widget? statusRow,
  }) {
    final isThreadView =
        ConversationPresentationScope.maybeOf(context)?.isThreadView ?? false;
    final threadInfo = widget.message.threadInfo;
    final showThread =
        !isThreadView && threadInfo != null && threadInfo.replyCount > 0;

    final children = <Widget>[
      if (widget.showSenderName)
        Padding(
          padding: const EdgeInsets.only(bottom: senderHeaderBodyGap),
          child: SenderHeader(
            senderName:
                widget.message.sender.name ??
                'User ${widget.message.sender.uid}',
            gender: widget.message.sender.gender,
          ),
        ),
      if (widget.message.replyToMessage != null)
        ReplyQuote(
          reply: widget.message.replyToMessage!,
          onTap: widget.onTapReply,
        ),
      body,
      if (statusRow != null) ...[const SizedBox(height: 6), statusRow],
      if (showThread) ...[
        const SizedBox(height: 4),
        ThreadIndicator(threadInfo: threadInfo, onTap: widget.onOpenThread),
      ],
    ];

    final bubble = Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: theme.bubbleColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: children,
      ),
    );

    if (widget.message.reactions.isEmpty) {
      return bubble;
    }

    return Column(
      crossAxisAlignment: theme.isMe
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        bubble,
        const SizedBox(height: 8),
        BubbleReactions(
          reactions: widget.message.reactions,
          onToggleReaction: widget.onToggleReaction,
        ),
      ],
    );
  }

  Widget _statusRow({
    required BubbleThemeV2 theme,
    required String text,
    required bool isError,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: appSecondaryTextStyle(context, fontSize: AppFontSizes.meta)
                .copyWith(
                  color: isError
                      ? CupertinoColors.systemRed.resolveFrom(context)
                      : theme.metaColor,
                ),
          ),
        ),
        const SizedBox(width: 8),
        MetaFooter(message: widget.message),
      ],
    );
  }

  Color _accentColor(BuildContext context, BubbleThemeV2 theme) => theme.isMe
      ? CupertinoColors.white
      : CupertinoColors.activeBlue.resolveFrom(context);

  Color _buttonBackground(
    BuildContext context,
    BubbleThemeV2 theme,
    Color accent,
  ) => theme.isMe ? CupertinoColors.white.withAlpha(36) : accent.withAlpha(28);

  Color _inactiveWaveformColor(BubbleThemeV2 theme, Color accent) =>
      theme.isMe ? CupertinoColors.white.withAlpha(92) : accent.withAlpha(72);

  double _measureStatusTextWidth(
    BuildContext context,
    BubbleThemeV2 theme,
    String text, {
    required bool isError,
  }) {
    final style = appSecondaryTextStyle(context, fontSize: AppFontSizes.meta)
        .copyWith(
          color: isError
              ? CupertinoColors.systemRed.resolveFrom(context)
              : theme.metaColor,
        );
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: double.infinity);
    return painter.width;
  }
}
