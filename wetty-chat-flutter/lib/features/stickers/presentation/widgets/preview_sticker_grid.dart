import 'package:flutter/cupertino.dart';

import '../../../../app/theme/style_config.dart';
import '../../../chats/conversation/presentation/message_bubble/sticker_image_widget.dart';
import '../../../chats/models/message_models.dart';

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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Wrap(
        alignment: WrapAlignment.start,
        spacing: 4,
        runSpacing: 4,
        children: stickers.map((sticker) {
          final isSelected =
              sticker.id == (selectedStickerId ?? initialStickerId);
          return GestureDetector(
            onTap: () => onStickerSelected(sticker.id),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: isSelected
                    ? Border.all(color: colors.accentPrimary, width: 2)
                    : null,
                color: isSelected ? colors.accentPrimary.withAlpha(25) : null,
              ),
              child: StickerImage(
                media: sticker.media,
                emoji: sticker.emoji,
                size: 76,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
