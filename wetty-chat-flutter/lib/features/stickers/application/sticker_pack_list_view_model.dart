import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/models/stickers_api_models.dart';
import '../data/sticker_api_service.dart';
import '../data/sticker_pack_order_store.dart';
import '../models/sticker_api_mapper.dart';
import '../models/sticker_models.dart';
import 'sticker_picker_view_model.dart';

List<StickerPackSummary> _sortPacksByOrder(
  List<StickerPackSummary> packs,
  List<StickerPackOrderItem> order,
) {
  final orderMap = <String, int>{};
  for (final item in order) {
    orderMap[item.stickerPackId] = item.lastUsedOn;
  }
  final ordered = <StickerPackSummary>[];
  final unordered = <StickerPackSummary>[];
  for (final pack in packs) {
    if (orderMap.containsKey(pack.id)) {
      ordered.add(pack);
    } else {
      unordered.add(pack);
    }
  }
  ordered.sort((a, b) => (orderMap[b.id] ?? 0).compareTo(orderMap[a.id] ?? 0));
  return [...ordered, ...unordered];
}

class StickerPackListState {
  const StickerPackListState({this.packs = const [], this.isLoading = false});

  final List<StickerPackSummary> packs;
  final bool isLoading;

  StickerPackListState copyWith({
    List<StickerPackSummary>? packs,
    bool? isLoading,
  }) {
    return StickerPackListState(
      packs: packs ?? this.packs,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class StickerPackListViewModel extends Notifier<StickerPackListState> {
  @override
  StickerPackListState build() => const StickerPackListState();

  StickerApiService get _api => ref.read(stickerApiServiceProvider);

  /// Fetches owned and subscribed packs in parallel and merges them.
  /// Shows cached packs immediately while refreshing from network
  /// (stale-while-revalidate).
  Future<void> loadPacks() async {
    final hasCachedPacks = state.packs.isNotEmpty;
    if (!hasCachedPacks) {
      state = state.copyWith(isLoading: true);
    }
    try {
      final results = await Future.wait([
        _api.fetchOwnedPacks(),
        _api.fetchSubscribedPacks(),
      ]);
      final ownedPacks = results[0].packs.map((p) => p.toDomain()).toList();
      final subscribedPacks = results[1].packs
          .map((p) => p.toDomain())
          .toList();

      // Deduplicate: owned packs first, then subscribed packs not already in owned.
      final ownedIds = ownedPacks.map((p) => p.id).toSet();
      final merged = [
        ...ownedPacks,
        ...subscribedPacks.where((p) => !ownedIds.contains(p.id)),
      ];

      final packOrder = ref.read(stickerPackOrderProvider).packOrder;
      final sorted = _sortPacksByOrder(merged, packOrder);

      state = state.copyWith(packs: sorted, isLoading: false);
    } catch (e, st) {
      debugPrint('Failed to load sticker packs: $e');
      debugPrint('$st');
      state = state.copyWith(isLoading: false);
    }
  }

  /// Creates a new sticker pack and prepends it to the list.
  /// Returns the created pack on success, or null on failure.
  Future<StickerPackSummary?> createPack(String name) async {
    try {
      final response = await _api.createPack(
        CreateStickerPackRequestDto(name: name),
      );
      final pack = response.toDomain();
      state = state.copyWith(packs: [pack, ...state.packs]);
      ref.invalidate(stickerPickerViewModelProvider);
      return pack;
    } catch (e, st) {
      debugPrint('Failed to create sticker pack: $e');
      debugPrint('$st');
      return null;
    }
  }

  /// Deletes a sticker pack and removes it from the local list.
  Future<void> deletePack(String packId) async {
    try {
      await _api.deletePack(packId);
      state = state.copyWith(
        packs: state.packs.where((p) => p.id != packId).toList(),
      );
      ref.read(stickerPackOrderProvider.notifier).removePackOrder(packId);
      ref.invalidate(stickerPickerViewModelProvider);
    } catch (e, st) {
      debugPrint('Failed to delete sticker pack: $e');
      debugPrint('$st');
    }
  }

  /// Unsubscribes from a sticker pack and removes it from the local list.
  Future<void> unsubscribePack(String packId) async {
    try {
      await _api.unsubscribeFromPack(packId);
      state = state.copyWith(
        packs: state.packs.where((p) => p.id != packId).toList(),
      );
      ref.read(stickerPackOrderProvider.notifier).removePackOrder(packId);
      ref.invalidate(stickerPickerViewModelProvider);
    } catch (e, st) {
      debugPrint('Failed to unsubscribe from sticker pack: $e');
      debugPrint('$st');
    }
  }
}

final stickerPackListViewModelProvider =
    NotifierProvider<StickerPackListViewModel, StickerPackListState>(
      StickerPackListViewModel.new,
    );
