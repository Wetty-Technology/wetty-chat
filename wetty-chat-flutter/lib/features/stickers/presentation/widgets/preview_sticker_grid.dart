import 'package:flutter/cupertino.dart';

import '../../../../app/theme/style_config.dart';
import '../../../chats/conversation/presentation/message_bubble/sticker_image_widget.dart';
import '../../../chats/models/message_models.dart';
import 'sticker_grid_layout.dart';

class PreviewStickerGrid extends StatelessWidget {
  const PreviewStickerGrid({
    super.key,
    required this.stickers,
    this.selectedStickerId,
    required this.initialStickerId,
    required this.onStickerSelected,
  });

  final List<StickerSummary> stickers;
  final String? selectedStickerId;
  final String initialStickerId;
  final ValueChanged<String?> onStickerSelected;

  @override
  Widget build(BuildContext context) {
    if (stickers.isEmpty) return const SizedBox.shrink();

    final colors = context.appColors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = StickerGridLayout.fromWidth(
          constraints.maxWidth,
          horizontalPadding: 8,
          crossAxisSpacing: 4,
        );

        return GridView.builder(
          key: const Key('preview-sticker-grid'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          gridDelegate: layout.buildDelegate(mainAxisSpacing: 4),
          itemCount: stickers.length,
          itemBuilder: (context, index) {
            final sticker = stickers[index];
            final isSelected =
                sticker.id == (selectedStickerId ?? initialStickerId);
            return GestureDetector(
              onTap: () => onStickerSelected(sticker.id),
              child: Container(
                key: ValueKey('preview-sticker-${sticker.id ?? index}'),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: isSelected
                      ? Border.all(color: colors.accentPrimary, width: 2)
                      : null,
                  color: isSelected ? colors.accentPrimary.withAlpha(25) : null,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final imageSize = (constraints.maxWidth - 8).clamp(
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
          },
        );
      },
    );
  }
}
