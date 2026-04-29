import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chahua/features/shared/data/read_state_repository.dart';

import '../model/thread_list_item.dart';
import '../data/thread_list_v2_repository.dart';
import 'thread_list_v2_store.dart';

typedef ThreadListV2ViewState = ({
  List<ThreadListItem> threads,
  bool hasMore,
  bool isLoadingMore,
  bool isRefreshing,
  bool isLoading,
  String? errorMessage,
});

class ThreadListV2ViewModel extends AsyncNotifier<ThreadListV2ViewState> {
  @override
  Future<ThreadListV2ViewState> build() async {
    ref.listen<ThreadListV2StoreState>(threadListV2StoreProvider, (_, _) {
      _rebuildFromStore();
    });
    return _loadInitial();
  }

  Future<ThreadListV2ViewState> _loadInitial() async {
    await ref.read(threadListV2RepositoryProvider).loadThreads();
    final storeState = ref.read(threadListV2StoreProvider);
    return (
      threads: storeState.active.threads,
      hasMore: storeState.active.hasMore,
      isLoadingMore: false,
      isRefreshing: false,
      isLoading: false,
      errorMessage: null,
    );
  }

  void _rebuildFromStore() {
    final current = state.value;
    if (current == null) {
      return;
    }
    final storeState = ref.read(threadListV2StoreProvider);
    state = AsyncData((
      threads: storeState.active.threads,
      hasMore: storeState.active.hasMore,
      isLoadingMore: current.isLoadingMore,
      isRefreshing: current.isRefreshing,
      isLoading: false,
      errorMessage: current.errorMessage,
    ));
  }

  Future<void> loadMoreThreads() async {
    final current = state.value;
    if (current == null) {
      return;
    }
    if (!current.hasMore || current.isLoadingMore || current.threads.isEmpty) {
      return;
    }

    state = AsyncData((
      threads: current.threads,
      hasMore: current.hasMore,
      isLoadingMore: true,
      isRefreshing: current.isRefreshing,
      isLoading: false,
      errorMessage: current.errorMessage,
    ));
    try {
      await ref.read(threadListV2RepositoryProvider).loadMoreThreads();
    } catch (_) {
      // Silently fail pagination.
    } finally {
      final storeState = ref.read(threadListV2StoreProvider);
      final latest = state.value;
      if (latest != null) {
        state = AsyncData((
          threads: storeState.active.threads,
          hasMore: storeState.active.hasMore,
          isLoadingMore: false,
          isRefreshing: latest.isRefreshing,
          isLoading: false,
          errorMessage: latest.errorMessage,
        ));
      }
    }
  }

  Future<void> refreshThreads() async {
    final current = state.value;
    if (current == null) {
      return;
    }
    if (current.isLoadingMore || current.isRefreshing) {
      return;
    }

    state = AsyncData((
      threads: current.threads,
      hasMore: current.hasMore,
      isLoadingMore: current.isLoadingMore,
      isRefreshing: true,
      isLoading: false,
      errorMessage: current.errorMessage,
    ));
    try {
      final limit = current.threads.isEmpty ? 20 : current.threads.length;
      await ref.read(threadListV2RepositoryProvider).loadThreads(limit: limit);
      ref.read(readStateRepositoryProvider).resetThreadBaselines();
      final storeState = ref.read(threadListV2StoreProvider);
      state = AsyncData((
        threads: storeState.active.threads,
        hasMore: storeState.active.hasMore,
        isLoadingMore: false,
        isRefreshing: false,
        isLoading: false,
        errorMessage: null,
      ));
    } catch (error) {
      final latest = state.value;
      if (latest != null) {
        state = AsyncData((
          threads: latest.threads,
          hasMore: latest.hasMore,
          isLoadingMore: false,
          isRefreshing: false,
          isLoading: false,
          errorMessage: error.toString(),
        ));
      }
    }
  }
}

final threadListV2ViewModelProvider =
    AsyncNotifierProvider<ThreadListV2ViewModel, ThreadListV2ViewState>(
      ThreadListV2ViewModel.new,
    );
