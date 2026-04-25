import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chats/models/message_models.dart';
import '../data/sticker_api_service.dart';
import '../models/sticker_api_mapper.dart';
import '../models/sticker_models.dart';
import 'sticker_picker_view_model.dart';

const _sentinel = Object();

class StickerDetailState {
  const StickerDetailState({
    this.sticker,
    this.pack,
    this.packStickers = const [],
    this.isSubscribed = false,
  });

  final StickerSummary? sticker;
  final StickerPackSummary? pack;
  final List<StickerSummary> packStickers;
  final bool isSubscribed;

  StickerDetailState copyWith({
    Object? sticker = _sentinel,
    Object? pack = _sentinel,
    List<StickerSummary>? packStickers,
    bool? isSubscribed,
  }) {
    return StickerDetailState(
      sticker: sticker == _sentinel ? this.sticker : sticker as StickerSummary?,
      pack: pack == _sentinel ? this.pack : pack as StickerPackSummary?,
      packStickers: packStickers ?? this.packStickers,
      isSubscribed: isSubscribed ?? this.isSubscribed,
    );
  }
}

class StickerDetailViewModel extends AsyncNotifier<StickerDetailState> {
  final String arg;

  StickerDetailViewModel(this.arg);

  @override
  Future<StickerDetailState> build() async {
    final stickerId = arg;
    final api = ref.read(stickerApiServiceProvider);

    // Fetch sticker detail (returns sticker + packs it belongs to).
    final detailDto = await api.fetchStickerDetail(stickerId);
    final sticker = detailDto.toStickerSummary();

    // Get the first pack, if any.
    if (detailDto.packs.isEmpty) {
      return StickerDetailState(sticker: sticker);
    }
    final packSummary = detailDto.packs.first.toDomain();

    // Fetch full pack detail to get all stickers.
    final packDetailDto = await api.fetchPackDetail(packSummary.id);
    final packStickers = packDetailDto.stickers
        .map(StickerSummary.fromDto)
        .toList();

    return StickerDetailState(
      sticker: sticker,
      pack: packSummary,
      packStickers: packStickers,
      isSubscribed: packSummary.isSubscribed,
    );
  }

  /// Optimistically toggles subscription for the current pack.
  Future<void> toggleSubscription() async {
    final current = state.value;
    if (current == null) return;
    final pack = current.pack;
    if (pack == null) return;

    final api = ref.read(stickerApiServiceProvider);
    final wasSubscribed = current.isSubscribed;

    // Optimistic update
    state = AsyncData(current.copyWith(isSubscribed: !wasSubscribed));

    try {
      if (wasSubscribed) {
        await api.unsubscribeFromPack(pack.id);
      } else {
        await api.subscribeToPack(pack.id);
      }
      // Invalidate picker VM to refresh pack list.
      ref.invalidate(stickerPickerViewModelProvider);
    } catch (e, st) {
      debugPrint('Failed to toggle subscription: $e');
      debugPrint('$st');
      // Revert on error
      state = AsyncData(current.copyWith(isSubscribed: wasSubscribed));
    }
  }
}

final stickerDetailViewModelProvider =
    AsyncNotifierProvider.family<
      StickerDetailViewModel,
      StickerDetailState,
      String
    >(StickerDetailViewModel.new);
