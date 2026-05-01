import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chahua/core/api/services/sticker_api_service.dart';
import 'package:chahua/features/shared/model/message/message.dart';
import '../data/sticker_pack_order_store.dart';
import '../models/sticker_models.dart';

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

class StickerPickerState {
  const StickerPickerState({
    this.packs = const [],
    this.favorites = const [],
    this.selectedPackId,
    this.packStickers = const {},
    this.isLoadingPacks = false,
    this.loadingPackId,
  });

  /// Merged list of owned + subscribed packs.
  final List<StickerPackSummary> packs;

  /// User's favorited stickers.
  final List<StickerSummary> favorites;

  /// Currently selected pack ID, or null for the favorites tab.
  final String? selectedPackId;

  /// Cached stickers for each pack, keyed by pack ID.
  final Map<String, List<StickerSummary>> packStickers;

  /// Whether the initial pack list is loading.
  final bool isLoadingPacks;

  /// The pack ID currently being loaded, if any.
  final String? loadingPackId;

  /// The stickers to display in the grid based on the current selection.
  List<StickerSummary> get currentStickers {
    final packId = selectedPackId;
    if (packId == null) return favorites;
    return packStickers[packId] ?? const [];
  }

  /// Whether the currently selected tab is still loading its stickers.
  bool get isLoadingCurrentStickers {
    final packId = selectedPackId;
    if (packId == null) return false;
    return loadingPackId == packId && !packStickers.containsKey(packId);
  }

  StickerPickerState copyWith({
    List<StickerPackSummary>? packs,
    List<StickerSummary>? favorites,
    Object? selectedPackId = _sentinel,
    Map<String, List<StickerSummary>>? packStickers,
    bool? isLoadingPacks,
    Object? loadingPackId = _sentinel,
  }) {
    return StickerPickerState(
      packs: packs ?? this.packs,
      favorites: favorites ?? this.favorites,
      selectedPackId: selectedPackId == _sentinel
          ? this.selectedPackId
          : selectedPackId as String?,
      packStickers: packStickers ?? this.packStickers,
      isLoadingPacks: isLoadingPacks ?? this.isLoadingPacks,
      loadingPackId: loadingPackId == _sentinel
          ? this.loadingPackId
          : loadingPackId as String?,
    );
  }
}

class StickerPickerViewModel extends Notifier<StickerPickerState> {
  @override
  StickerPickerState build() => const StickerPickerState();

  StickerApiService get _api => ref.read(stickerApiServiceProvider);

  /// Fetches owned and subscribed packs in parallel and merges them.
  /// Shows cached packs immediately while refreshing from network.
  Future<void> loadPacks() async {
    final hasCachedPacks = state.packs.isNotEmpty;
    if (!hasCachedPacks) {
      state = state.copyWith(isLoadingPacks: true);
    }
    try {
      final results = await Future.wait([
        _api.fetchOwnedPacks(),
        _api.fetchSubscribedPacks(),
      ]);
      final ownedPacks = results[0].packs
          .map(StickerPackSummary.fromDto)
          .toList();
      final subscribedPacks = results[1].packs
          .map(StickerPackSummary.fromDto)
          .toList();

      // Deduplicate: owned packs first, then subscribed packs not already in owned.
      final ownedIds = ownedPacks.map((p) => p.id).toSet();
      final merged = [
        ...ownedPacks,
        ...subscribedPacks.where((p) => !ownedIds.contains(p.id)),
      ];

      final packOrder = ref.read(stickerPackOrderProvider).packOrder;
      final sorted = _sortPacksByOrder(merged, packOrder);

      state = state.copyWith(packs: sorted, isLoadingPacks: false);
    } catch (e, st) {
      debugPrint('Failed to load sticker packs: $e');
      debugPrint('$st');
      state = state.copyWith(isLoadingPacks: false);
    }
  }

  /// Fetches the user's favorite stickers.
  /// Shows cached favorites immediately while refreshing from network.
  Future<void> loadFavorites() async {
    try {
      final response = await _api.fetchFavorites();
      final favorites = response.stickers.map(StickerSummary.fromDto).toList();
      state = state.copyWith(favorites: favorites);
    } catch (e, st) {
      debugPrint('Failed to load favorite stickers: $e');
      debugPrint('$st');
    }
  }

  /// Selects a pack tab and loads its stickers.
  /// Shows cached stickers immediately while refreshing from network.
  Future<void> selectPack(String packId) async {
    state = state.copyWith(selectedPackId: packId);

    final hasCached = state.packStickers.containsKey(packId);
    if (!hasCached) {
      state = state.copyWith(loadingPackId: packId);
    }
    try {
      final detail = await _api.fetchPackDetail(packId);
      final stickers = detail.stickers.map(StickerSummary.fromDto).toList();
      state = state.copyWith(
        packStickers: {...state.packStickers, packId: stickers},
        loadingPackId: null,
      );
    } catch (e, st) {
      debugPrint('Failed to load stickers for pack $packId: $e');
      debugPrint('$st');
      state = state.copyWith(loadingPackId: null);
    }
  }

  /// Selects the favorites tab.
  void selectFavorites() {
    state = state.copyWith(selectedPackId: null);
  }

  /// Records usage of a sticker pack for ordering purposes.
  void recordStickerUsage(String packId) {
    ref
        .read(stickerPackOrderProvider.notifier)
        .upsertPackOrder(packId, DateTime.now().millisecondsSinceEpoch);
    ref.read(stickerPackOrderProvider.notifier).syncToServer();
  }

  /// Optimistically toggles a sticker's favorite status in local state,
  /// then calls the API. Reverts on error.
  Future<void> toggleFavorite(String stickerId) async {
    final currentFavorites = state.favorites;
    final isFavorited = currentFavorites.any((s) => s.id == stickerId);

    if (isFavorited) {
      // Optimistic remove
      final updated = currentFavorites.where((s) => s.id != stickerId).toList();
      state = state.copyWith(favorites: updated);
      try {
        await _api.removeFavorite(stickerId);
      } catch (e, st) {
        debugPrint('Failed to remove favorite: $e');
        debugPrint('$st');
        // Revert
        state = state.copyWith(favorites: currentFavorites);
      }
    } else {
      // Find the sticker in pack stickers to add to favorites
      StickerSummary? sticker;
      for (final entry in state.packStickers.entries) {
        for (final s in entry.value) {
          if (s.id == stickerId) {
            sticker = s;
            break;
          }
        }
        if (sticker != null) break;
      }

      if (sticker != null) {
        final updated = [
          sticker.copyWith(isFavorited: true),
          ...currentFavorites,
        ];
        state = state.copyWith(favorites: updated);
      }

      try {
        await _api.addFavorite(stickerId);
      } catch (e, st) {
        debugPrint('Failed to add favorite: $e');
        debugPrint('$st');
        // Revert
        state = state.copyWith(favorites: currentFavorites);
      }
    }
  }
}

final stickerPickerViewModelProvider =
    NotifierProvider<StickerPickerViewModel, StickerPickerState>(
      StickerPickerViewModel.new,
    );

const _sentinel = Object();
