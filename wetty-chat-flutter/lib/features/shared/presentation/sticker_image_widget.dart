import 'package:chahua/core/cache/app_cached_network_image.dart';
import 'package:chahua/features/shared/model/message/message.dart';
import 'package:flutter/cupertino.dart';

/// Renders a sticker image or video placeholder.
///
/// Designed with a pluggable video slot so a real player can be swapped in
/// once video playback is re-enabled.
class StickerImage extends StatelessWidget {
  const StickerImage({
    super.key,
    this.media,
    this.emoji,
    this.size = 160,
    this.fit = BoxFit.contain,
  });

  final StickerMedia? media;
  final String? emoji;
  final double size;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final stickerMedia = media;
    if (stickerMedia == null || stickerMedia.url.isEmpty) {
      return _buildEmojiFallback();
    }
    if (stickerMedia.isVideo) {
      return _VideoStickerPlaceholder(emoji: emoji, size: size);
    }
    return _buildImage(stickerMedia);
  }

  Widget _buildImage(StickerMedia stickerMedia) {
    final cacheWidth = (size * 2).round();
    return SizedBox(
      width: size,
      height: size,
      child: AppCachedNetworkImage(
        imageUrl: stickerMedia.url,
        fit: fit,
        memCacheWidth: cacheWidth,
        placeholder: (_, _) => _buildLoadingPlaceholder(),
        errorWidget: (_, _, _) => _buildEmojiFallback(),
      ),
    );
  }

  Widget _buildLoadingPlaceholder() {
    return SizedBox(
      width: size,
      height: size,
      child: const Center(child: CupertinoActivityIndicator(radius: 10)),
    );
  }

  Widget _buildEmojiFallback() {
    final emojiText = emoji?.trim();
    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Text(
          emojiText != null && emojiText.isNotEmpty ? emojiText : '🏷️',
          style: TextStyle(fontSize: size * 0.5),
        ),
      ),
    );
  }
}

/// Placeholder for video stickers while video playback is disabled.
/// This widget is the swap-point for a real video player later.
class _VideoStickerPlaceholder extends StatelessWidget {
  const _VideoStickerPlaceholder({this.emoji, required this.size});

  final String? emoji;
  final double size;

  @override
  Widget build(BuildContext context) {
    final emojiText = emoji?.trim();
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF272727), Color(0xFF151515)],
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (emojiText != null && emojiText.isNotEmpty)
              Text(emojiText, style: TextStyle(fontSize: size * 0.35))
            else
              Icon(
                CupertinoIcons.play_rectangle,
                color: CupertinoColors.white.withAlpha(180),
                size: size * 0.3,
              ),
            Positioned(
              right: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: CupertinoColors.black.withAlpha(140),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      CupertinoIcons.film,
                      color: CupertinoColors.white,
                      size: 10,
                    ),
                    SizedBox(width: 2),
                    Text(
                      'Video',
                      style: TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
