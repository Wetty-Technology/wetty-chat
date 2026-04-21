import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/message_models.dart';
import '../../conversation/data/video_thumbnail_service.dart';

class VideoAttachmentThumbnail extends ConsumerWidget {
  const VideoAttachmentThumbnail({
    super.key,
    required this.attachment,
    this.fit = BoxFit.cover,
  });

  final AttachmentItem attachment;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumbnail = ref.watch(videoThumbnailBytesProvider(attachment));
    return thumbnail.when(
      data: (bytes) {
        if (bytes == null || bytes.isEmpty) {
          return VideoAttachmentThumbnailPlaceholder(attachment: attachment);
        }
        return Image.memory(
          bytes,
          key: ValueKey('video-thumbnail-image-${attachment.id}'),
          fit: fit,
          gaplessPlayback: true,
        );
      },
      loading: () =>
          VideoAttachmentThumbnailPlaceholder(attachment: attachment),
      error: (_, _) =>
          VideoAttachmentThumbnailPlaceholder(attachment: attachment),
    );
  }
}

class VideoAttachmentThumbnailPlaceholder extends StatelessWidget {
  const VideoAttachmentThumbnailPlaceholder({
    super.key,
    required this.attachment,
  });

  final AttachmentItem attachment;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: ValueKey('video-thumbnail-placeholder-${attachment.id}'),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF272727), Color(0xFF151515)],
        ),
      ),
      child: Container(color: CupertinoColors.black.withAlpha(18)),
    );
  }
}
