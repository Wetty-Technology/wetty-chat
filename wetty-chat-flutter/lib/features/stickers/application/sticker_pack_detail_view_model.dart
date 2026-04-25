import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chahua/features/shared/model/message/message.dart';
import '../data/sticker_api_service.dart';
import '../models/sticker_api_mapper.dart';
import '../models/sticker_models.dart';
import 'sticker_pack_list_view_model.dart';
import 'sticker_picker_view_model.dart';

class StickerPackDetailState {
  const StickerPackDetailState({required this.pack, this.stickers = const []});

  final StickerPackDetail pack;
  final List<StickerSummary> stickers;

  StickerPackDetailState copyWith({
    StickerPackDetail? pack,
    List<StickerSummary>? stickers,
  }) {
    return StickerPackDetailState(
      pack: pack ?? this.pack,
      stickers: stickers ?? this.stickers,
    );
  }
}

class StickerPackDetailViewModel extends AsyncNotifier<StickerPackDetailState> {
  final String arg;

  StickerPackDetailViewModel(this.arg);

  @override
  Future<StickerPackDetailState> build() async {
    final api = ref.read(stickerApiServiceProvider);
    final detailDto = await api.fetchPackDetail(arg);
    final packDetail = detailDto.toDomain();

    return StickerPackDetailState(
      pack: packDetail,
      stickers: packDetail.stickers,
    );
  }

  /// Removes a sticker from this pack via the API and updates local state.
  Future<void> removeSticker(String stickerId) async {
    final current = state.value;
    if (current == null) return;

    final api = ref.read(stickerApiServiceProvider);
    try {
      await api.removeStickerFromPack(arg, stickerId);
      state = AsyncData(
        current.copyWith(
          stickers: current.stickers.where((s) => s.id != stickerId).toList(),
        ),
      );
    } catch (e, st) {
      debugPrint('Failed to remove sticker from pack: $e');
      debugPrint('$st');
    }
  }

  /// Adds a sticker to the local list (called after successful upload).
  Future<void> addSticker(StickerSummary sticker) async {
    final current = state.value;
    if (current == null) return;

    state = AsyncData(
      current.copyWith(stickers: [...current.stickers, sticker]),
    );
  }

  /// Deletes this pack via the API and invalidates related providers.
  Future<void> deletePack() async {
    final api = ref.read(stickerApiServiceProvider);
    try {
      await api.deletePack(arg);
      ref.invalidate(stickerPickerViewModelProvider);
      ref.invalidate(stickerPackListViewModelProvider);
    } catch (e, st) {
      debugPrint('Failed to delete sticker pack: $e');
      debugPrint('$st');
    }
  }

  /// Unsubscribes from this pack via the API and invalidates related providers.
  Future<void> unsubscribePack() async {
    final api = ref.read(stickerApiServiceProvider);
    try {
      await api.unsubscribeFromPack(arg);
      ref.invalidate(stickerPickerViewModelProvider);
      ref.invalidate(stickerPackListViewModelProvider);
    } catch (e, st) {
      debugPrint('Failed to unsubscribe from sticker pack: $e');
      debugPrint('$st');
    }
  }
}

final stickerPackDetailViewModelProvider =
    AsyncNotifierProvider.family<
      StickerPackDetailViewModel,
      StickerPackDetailState,
      String
    >(StickerPackDetailViewModel.new);
