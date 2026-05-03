import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chahua/app/routing/route_names.dart';
import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/features/shared/model/message/message.dart';
import 'package:chahua/features/shared/presentation/adaptive_cupertino_popup.dart';
import 'package:chahua/features/shared/presentation/sticker_image_widget.dart';
import '../application/sticker_detail_view_model.dart';
import 'widgets/preview_action_button.dart';
import 'widgets/preview_header.dart';
import 'widgets/preview_sticker_grid.dart';

/// Shows an adaptive Cupertino-style preview for a sticker and its pack.
Future<void> showStickerPreviewModal(
  BuildContext context,
  String stickerId,
) async {
  final selectedPackId = await showAdaptiveCupertinoPopup<String>(
    context: context,
    builder: (context) => _StickerPreviewPanel(stickerId: stickerId),
  );

  if (!context.mounted || selectedPackId == null) {
    return;
  }

  debugPrint(
    '[stickers] preview manage navigating to pack detail: '
    'stickerId=$stickerId packId=$selectedPackId',
  );
  context.push(AppRoutes.stickerPackDetail(selectedPackId));
}

class _StickerPreviewPanel extends ConsumerStatefulWidget {
  const _StickerPreviewPanel({required this.stickerId});

  final String stickerId;

  @override
  ConsumerState<_StickerPreviewPanel> createState() =>
      _StickerPreviewPanelState();
}

class _StickerPreviewPanelState extends ConsumerState<_StickerPreviewPanel> {
  String? _selectedStickerId;

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(
      stickerDetailViewModelProvider(widget.stickerId),
    );
    final colors = context.appColors;

    return ColoredBox(
      color: CupertinoColors.systemBackground.resolveFrom(context),
      child: asyncState.when(
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (error, _) => _buildError(colors, error),
        data: (state) => _buildContent(context, colors, state),
      ),
    );
  }

  Widget _buildError(AppColors colors, Object error) {
    return SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PreviewHeader(packName: null),
          Expanded(
            child: Center(
              child: Text(
                'Failed to load sticker details',
                style: appBodyTextStyle(context, color: colors.textSecondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppColors colors,
    StickerDetailState state,
  ) {
    final heroSticker = _selectedStickerId != null
        ? state.packStickers.firstWhere(
            (s) => s.id == _selectedStickerId,
            orElse: () =>
                state.sticker ?? const StickerSummary(id: 'preview-fallback'),
          )
        : state.sticker;

    return SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PreviewHeader(packName: state.pack?.name),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeroSection(colors, heroSticker),
                  if (state.pack != null) ...[
                    _buildPackHeader(colors, state),
                    PreviewStickerGrid(
                      stickers: state.packStickers,
                      selectedStickerId: _selectedStickerId,
                      initialStickerId: widget.stickerId,
                      onStickerSelected: (id) {
                        setState(() {
                          _selectedStickerId = id;
                        });
                      },
                    ),
                    // Spacer for floating action button
                    const SizedBox(height: 72),
                  ],
                ],
              ),
            ),
          ),
          PreviewActionButton(
            state: state,
            stickerId: widget.stickerId,
            onToggleSubscription: _onToggleSubscription,
            onManagePack: _onManagePack,
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(AppColors colors, StickerSummary? sticker) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          StickerImage(media: sticker?.media, emoji: sticker?.emoji, size: 180),
          if (sticker?.emoji != null && sticker!.emoji!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(sticker.emoji!, style: const TextStyle(fontSize: 24)),
            ),
        ],
      ),
    );
  }

  Widget _buildPackHeader(AppColors colors, StickerDetailState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              state.pack?.name ?? '',
              style: appTitleTextStyle(
                context,
                fontSize: AppFontSizes.appTitle,
              ),
            ),
          ),
          Text(
            '${state.packStickers.length} stickers',
            style: appMetaTextStyle(context),
          ),
        ],
      ),
    );
  }

  void _onToggleSubscription() {
    ref
        .read(stickerDetailViewModelProvider(widget.stickerId).notifier)
        .toggleSubscription();
  }

  void _onManagePack(String packId) {
    debugPrint(
      '[stickers] preview manage requested: '
      'stickerId=${widget.stickerId} packId=$packId',
    );
    Navigator.of(context, rootNavigator: true).pop(packId);
  }
}
