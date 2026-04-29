import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/thread_list_v2_repository.dart';
import '../model/thread_list_item.dart';
import 'thread_list_v2_store.dart';

typedef ArchivedThreadListV2ViewState = ({
  List<ThreadListItem> threads,
  bool hasMore,
  bool isLoadingMore,
  bool isRefreshing,
  bool isLoading,
  String? errorMessage,
});

class ArchivedThreadListV2ViewModel
    extends AsyncNotifier<ArchivedThreadListV2ViewState> {
  @override
  Future<ArchivedThreadListV2ViewState> build() async {
    ref.listen<ThreadListV2StoreState>(threadListV2StoreProvider, (_, _) {
      _rebuildFromStore();
    });
    return _loadInitial();
  }

  Future<ArchivedThreadListV2ViewState> _loadInitial() async {
    final archived = ref.read(threadListV2StoreProvider).archived;
    if (!archived.isLoaded) {
      await ref.read(threadListV2RepositoryProvider).loadArchivedThreads();
    }
    final storeState = ref.read(threadListV2StoreProvider);
    return (
      threads: storeState.archived.threads,
      hasMore: storeState.archived.hasMore,
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
      threads: storeState.archived.threads,
      hasMore: storeState.archived.hasMore,
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
      await ref.read(threadListV2RepositoryProvider).loadMoreArchivedThreads();
    } catch (_) {
      // Silently fail pagination.
    } finally {
      final storeState = ref.read(threadListV2StoreProvider);
      final latest = state.value;
      if (latest != null) {
        state = AsyncData((
          threads: storeState.archived.threads,
          hasMore: storeState.archived.hasMore,
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
      await ref
          .read(threadListV2RepositoryProvider)
          .loadArchivedThreads(limit: limit);
      final storeState = ref.read(threadListV2StoreProvider);
      state = AsyncData((
        threads: storeState.archived.threads,
        hasMore: storeState.archived.hasMore,
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

final archivedThreadListV2ViewModelProvider =
    AsyncNotifierProvider<
      ArchivedThreadListV2ViewModel,
      ArchivedThreadListV2ViewState
    >(ArchivedThreadListV2ViewModel.new);
