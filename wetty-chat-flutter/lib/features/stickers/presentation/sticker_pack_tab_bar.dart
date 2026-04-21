import 'package:flutter/cupertino.dart';

import '../../../app/theme/style_config.dart';
import 'package:chahua/features/chats/shared/presentation/sticker_image_widget.dart';
import '../models/sticker_models.dart';

/// Horizontal tab bar at the bottom of the sticker picker.
///
/// Displays a star icon for the favorites tab followed by one tab per pack.
/// The active tab is indicated by a colored underline.
class StickerPackTabBar extends StatelessWidget {
  const StickerPackTabBar({
    super.key,
    required this.packs,
    required this.selectedPackId,
    required this.onPackSelected,
  });

  final List<StickerPackSummary> packs;

  /// Currently selected pack ID, or null when the favorites tab is active.
  final String? selectedPackId;

  final ValueChanged<String?> onPackSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isFavoritesSelected = selectedPackId == null;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.separator, width: 0.5)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: packs.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _FavoritesTab(
              isSelected: isFavoritesSelected,
              onTap: () => onPackSelected(null),
            );
          }
          final pack = packs[index - 1];
          final isSelected = selectedPackId == pack.id;
          return _PackTab(
            pack: pack,
            isSelected: isSelected,
            onTap: () => onPackSelected(pack.id),
          );
        },
      ),
    );
  }
}

class _FavoritesTab extends StatelessWidget {
  const _FavoritesTab({required this.isSelected, required this.onTap});

  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected
                  ? colors.accentPrimary
                  : const Color(0x00000000),
              width: 2,
            ),
          ),
        ),
        child: Icon(
          CupertinoIcons.star_fill,
          size: 22,
          color: isSelected ? colors.accentPrimary : colors.textSecondary,
        ),
      ),
    );
  }
}

class _PackTab extends StatelessWidget {
  const _PackTab({
    required this.pack,
    required this.isSelected,
    required this.onTap,
  });

  final StickerPackSummary pack;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final preview = pack.previewSticker;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected
                  ? colors.accentPrimary
                  : const Color(0x00000000),
              width: 2,
            ),
          ),
        ),
        child: preview != null
            ? StickerImage(media: preview.media, emoji: preview.emoji, size: 24)
            : Text(
                pack.name.isNotEmpty ? pack.name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? colors.accentPrimary
                      : colors.textSecondary,
                ),
              ),
      ),
    );
  }
}
