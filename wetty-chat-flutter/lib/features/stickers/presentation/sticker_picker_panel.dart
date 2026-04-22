import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/style_config.dart';
import 'package:chahua/features/chats/shared/presentation/sticker_image_widget.dart';
import '../../chats/models/message_models.dart';
import '../application/sticker_picker_view_model.dart';
import 'sticker_pack_tab_bar.dart';
import 'widgets/sticker_grid_layout.dart';

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

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = StickerGridLayout.fromWidth(
          constraints.maxWidth,
          horizontalPadding: 8,
          crossAxisSpacing: 4,
        );

        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: layout.buildDelegate(mainAxisSpacing: 4),
          itemCount: stickers.length,
          itemBuilder: (context, index) {
            final sticker = stickers[index];
            return _StickerGridCell(
              key: ValueKey('picker-sticker-${sticker.id}'),
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
    ref.read(stickerPickerViewModelProvider.notifier).toggleFavorite(stickerId);
  }
}

class _StickerGridCell extends StatelessWidget {
  const _StickerGridCell({
    super.key,
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
  }
}
