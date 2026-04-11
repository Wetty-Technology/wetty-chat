import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/style_config.dart';
import '../../chats/conversation/presentation/message_bubble/sticker_image_widget.dart';
import '../../chats/models/message_models.dart';
import '../application/sticker_picker_view_model.dart';
import '../data/sticker_pack_order_sync.dart';
import 'sticker_pack_tab_bar.dart';

/// Panel that displays a sticker picker grid with a pack tab bar.
///
/// Designed to sit at the bottom of the conversation screen, similar to a
/// keyboard. Fixed height of 260px.
class StickerPickerPanel extends ConsumerStatefulWidget {
  const StickerPickerPanel({
    super.key,
    required this.onStickerSelected,
    this.onClose,
  });

  final ValueChanged<StickerSummary> onStickerSelected;
  final VoidCallback? onClose;

  @override
  ConsumerState<StickerPickerPanel> createState() => _StickerPickerPanelState();
}

class _StickerPickerPanelState extends ConsumerState<StickerPickerPanel> {
  @override
  void initState() {
    super.initState();
    Future(() {
      final notifier = ref.read(stickerPickerViewModelProvider.notifier);
      notifier.loadPacks();
      notifier.loadFavorites();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Keep WS sync alive while picker is mounted.
    ref.watch(stickerPackOrderSyncProvider);
    final pickerState = ref.watch(stickerPickerViewModelProvider);
    final colors = context.appColors;

    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: colors.backgroundSecondary,
        border: Border(top: BorderSide(color: colors.separator, width: 0.5)),
      ),
      child: Column(
        children: [
          Expanded(child: _buildStickerGrid(pickerState, colors)),
          StickerPackTabBar(
            packs: pickerState.packs,
            selectedPackId: pickerState.selectedPackId,
            onPackSelected: _onPackSelected,
          ),
        ],
      ),
    );
  }

  Widget _buildStickerGrid(StickerPickerState pickerState, AppColors colors) {
    if (pickerState.isLoadingPacks || pickerState.isLoadingCurrentStickers) {
      return const Center(child: CupertinoActivityIndicator());
    }

    final stickers = pickerState.currentStickers;
    if (stickers.isEmpty) {
      return Center(
        child: Text(
          'No stickers',
          style: TextStyle(color: colors.textSecondary, fontSize: 14),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: stickers.length,
      itemBuilder: (context, index) {
        final sticker = stickers[index];
        return _StickerGridCell(
          sticker: sticker,
          onTap: () {
            final packId = pickerState.selectedPackId;
            if (packId != null) {
              ref
                  .read(stickerPickerViewModelProvider.notifier)
                  .recordStickerUsage(packId);
            }
            widget.onStickerSelected(sticker);
          },
          onToggleFavorite: () => _onToggleFavorite(sticker),
        );
      },
    );
  }

  void _onPackSelected(String? packId) {
    final notifier = ref.read(stickerPickerViewModelProvider.notifier);
    if (packId == null) {
      notifier.selectFavorites();
    } else {
      notifier.selectPack(packId);
    }
  }

  void _onToggleFavorite(StickerSummary sticker) {
    final stickerId = sticker.id;
    if (stickerId == null) return;
    ref.read(stickerPickerViewModelProvider.notifier).toggleFavorite(stickerId);
  }
}

class _StickerGridCell extends StatelessWidget {
  const _StickerGridCell({
    required this.sticker,
    required this.onTap,
    required this.onToggleFavorite,
  });

  final StickerSummary sticker;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final isFavorited = sticker.isFavorited ?? false;
    return CupertinoContextMenu(
      actions: [
        CupertinoContextMenuAction(
          onPressed: () {
            Navigator.of(context, rootNavigator: true).pop();
            onToggleFavorite();
          },
          trailingIcon: isFavorited
              ? CupertinoIcons.star_slash
              : CupertinoIcons.star,
          child: Text(
            isFavorited ? 'Remove from Favorites' : 'Add to Favorites',
          ),
        ),
      ],
      child: GestureDetector(
        onTap: onTap,
        child: StickerImage(
          media: sticker.media,
          emoji: sticker.emoji,
          size: 80,
        ),
      ),
    );
  }
}
