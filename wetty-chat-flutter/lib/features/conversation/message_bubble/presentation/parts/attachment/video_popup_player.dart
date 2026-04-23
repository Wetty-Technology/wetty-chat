import 'package:flutter/cupertino.dart';

import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/features/chats/models/message_models.dart';
import 'message_attachment_previews.dart';
import 'video_attachment_thumbnail.dart';

class VideoAttachmentPreview extends StatelessWidget {
  const VideoAttachmentPreview({
    super.key,
    required this.attachment,
    required this.onTap,
    required this.maxWidth,
    this.maxHeight = 300,
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
    this.frameWidth,
    this.frameHeight,
    this.fit = BoxFit.cover,
  });

  final AttachmentItem attachment;
  final VoidCallback onTap;
  final double maxWidth;
  final double maxHeight;
  final BorderRadius? borderRadius;
  final double? frameWidth;
  final double? frameHeight;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final layout = computeAttachmentPreviewLayout(
      attachment,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
    final previewWidth =
        frameWidth ?? layout?.width ?? maxWidth.clamp(0, 220).toDouble();
    final previewHeight =
        frameHeight ?? layout?.height ?? maxHeight.clamp(0, 220).toDouble();

    Widget preview = SizedBox(
      width: previewWidth,
      height: previewHeight,
      child: Stack(
        fit: StackFit.expand,
        children: [
          VideoAttachmentThumbnail(attachment: attachment, fit: fit),
          Container(color: CupertinoColors.black.withAlpha(36)),
          if (attachment.duration case final duration?)
            Positioned(
              left: 12,
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: CupertinoColors.black.withAlpha(96),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _formatDuration(duration),
                  style: appOnDarkTextStyle(
                    context,
                    fontSize: AppFontSizes.meta,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          Center(
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: CupertinoColors.black.withAlpha(110),
                shape: BoxShape.circle,
                border: Border.all(color: CupertinoColors.white.withAlpha(70)),
              ),
              alignment: Alignment.center,
              child: const Icon(
                CupertinoIcons.play_fill,
                color: CupertinoColors.white,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
    if (borderRadius != null) {
      preview = ClipRRect(borderRadius: borderRadius!, child: preview);
    }

    return GestureDetector(onTap: onTap, child: preview);
  }
}

String _formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final minutes = (totalSeconds ~/ 60).toString();
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  final hours = duration.inHours;
  if (hours > 0) {
    final remainingMinutes = (duration.inMinutes % 60).toString().padLeft(
      2,
      '0',
    );
    return '$hours:$remainingMinutes:$seconds';
  }
  return '$minutes:$seconds';
}
