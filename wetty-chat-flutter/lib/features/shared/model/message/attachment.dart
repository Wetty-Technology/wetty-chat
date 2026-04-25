import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:chahua/core/api/models/messages_api_models.dart';

part 'attachment.freezed.dart';

@freezed
abstract class AttachmentItem with _$AttachmentItem {
  const AttachmentItem._();

  const factory AttachmentItem({
    required String id,
    required String url,
    required String kind,
    required int size,
    required String fileName,
    int? width,
    int? height,
    int? durationMs,
    List<int>? waveformSamples,
  }) = _AttachmentItem;

  bool get isImage => kind.startsWith('image/');
  bool get isVideo => kind.startsWith('video/');
  bool get isAudio => kind.startsWith('audio/');
  bool get hasWaveform =>
      waveformSamples != null && waveformSamples!.isNotEmpty;
  Duration? get duration =>
      durationMs == null ? null : Duration(milliseconds: durationMs!);

  factory AttachmentItem.fromDto(AttachmentItemDto dto) => AttachmentItem(
    id: dto.id,
    url: dto.url,
    kind: dto.kind,
    size: dto.size,
    fileName: dto.fileName,
    width: dto.width,
    height: dto.height,
  );
}
