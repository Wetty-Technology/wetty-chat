import 'package:flutter/cupertino.dart';

import '../../../../app/theme/style_config.dart';
import '../../../chats/conversation/presentation/message_bubble/sticker_image_widget.dart';
import '../../../chats/models/message_models.dart';

class StickerGridItem extends StatelessWidget {
  const StickerGridItem({super.key, required this.sticker, this.onTap});

  final StickerSummary sticker;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: colors.surfaceMuted,
        ),
        child: StickerImage(
          media: sticker.media,
          emoji: sticker.emoji,
          size: 78,
        ),
      ),
    );
  }
}
