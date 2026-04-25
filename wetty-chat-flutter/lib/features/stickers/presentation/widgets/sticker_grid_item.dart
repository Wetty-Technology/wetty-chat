import 'package:flutter/cupertino.dart';

import '../../../../app/theme/style_config.dart';
import 'package:chahua/features/shared/presentation/sticker_image_widget.dart';
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            final imageSize = (constraints.maxWidth - 10).clamp(
              0.0,
              double.infinity,
            );
            return Center(
              child: StickerImage(
                media: sticker.media,
                emoji: sticker.emoji,
                size: imageSize,
              ),
            );
          },
        ),
      ),
    );
  }
}
