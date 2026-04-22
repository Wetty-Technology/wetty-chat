import 'package:chahua/features/chats/conversation/data/audio_duration_probe_service.dart';
import 'package:chahua/features/chats/conversation_v2/data/audio_source_resolver_service.dart';
import 'package:chahua/features/chats/conversation_v2/data/audio_waveform_cache_service.dart';
import 'package:chahua/features/chats/models/message_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class VoiceMessagePresentationDataV2 {
  const VoiceMessagePresentationDataV2({
    required this.canPlay,
    required this.duration,
    required this.waveform,
  });

  final bool canPlay;
  final Duration? duration;
  final AudioWaveformSnapshot? waveform;
}

final voiceMessagePresentationV2Provider = FutureProvider.autoDispose
    .family<VoiceMessagePresentationDataV2, AttachmentItem>((
      ref,
      attachment,
    ) async {
      final sourceResolver = ref.watch(audioSourceResolverServiceProvider);
      final durationProbe = ref.watch(audioDurationProbeServiceProvider);
      final waveformCache = ref.watch(audioWaveformCacheServiceProvider);

      final source = await sourceResolver.resolvePlaybackSource(attachment);
      final duration =
          attachment.duration ??
          await durationProbe.resolveForAttachment(attachment, source: source);
      final waveform = await waveformCache.resolveForAttachment(
        attachment,
        preferredDuration: duration,
        waveformInputPath: source?.localWaveformPath,
      );

      return VoiceMessagePresentationDataV2(
        canPlay: source != null,
        duration: duration ?? waveform?.duration,
        waveform: waveform,
      );
    });
