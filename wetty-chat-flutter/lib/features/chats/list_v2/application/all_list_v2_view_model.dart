import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'all_list_v2_models.dart';
import 'all_list_v2_projection.dart';
import 'group_list_v2_view_model.dart';
import 'thread_list_v2_view_model.dart';

typedef AllListV2ViewState = ({
  List<AllListV2Item> items,
  bool hasAnyContent,
  bool isLoading,
  bool isRefreshing,
  bool isLoadingMore,
  bool groupsHasMore,
  bool threadsHasMore,
  String? errorMessage,
});

class AllListV2ViewModel extends AsyncNotifier<AllListV2ViewState> {
  @override
  Future<AllListV2ViewState> build() async {
    ref.listen<List<AllListV2Item>>(allListV2ItemsProvider, (_, _) {
      _rebuildFromSources();
    });
    ref.listen<AsyncValue<GroupListV2ViewState>>(groupListV2ViewModelProvider, (
      _,
      _,
    ) {
      _rebuildFromSources();
    });
    ref.listen<AsyncValue<ThreadListV2ViewState>>(
      threadListV2ViewModelProvider,
      (_, _) {
        _rebuildFromSources();
      },
    );

    final groupFuture = ref.read(groupListV2ViewModelProvider.future);
    final threadFuture = ref.read(threadListV2ViewModelProvider.future);
    await Future.wait([groupFuture, threadFuture]);
    return _buildState();
  }

  AllListV2ViewState _buildState({
    bool? isRefreshing,
    bool? isLoadingMore,
    String? errorMessage,
  }) {
    final items = ref.read(allListV2ItemsProvider);
    final groupState = ref.read(groupListV2ViewModelProvider).value;
    final threadState = ref.read(threadListV2ViewModelProvider).value;
    final loading =
        ref.read(groupListV2ViewModelProvider).isLoading &&
        ref.read(threadListV2ViewModelProvider).isLoading &&
        items.isEmpty;

    return (
      items: items,
      hasAnyContent: items.isNotEmpty,
      isLoading: loading,
      isRefreshing: isRefreshing ?? false,
      isLoadingMore: isLoadingMore ?? false,
      groupsHasMore: groupState?.hasMore ?? false,
      threadsHasMore: threadState?.hasMore ?? false,
      errorMessage: errorMessage,
    );
  }

  void _rebuildFromSources() {
    final current = state.value;
    if (current == null) {
      return;
    }

    state = AsyncData(
      _buildState(
        isRefreshing: current.isRefreshing,
        isLoadingMore: current.isLoadingMore,
        errorMessage: current.errorMessage,
      ),
    );
  }

  Future<void> refreshAll() async {
    final current = state.value;
    if (current == null || current.isRefreshing || current.isLoadingMore) {
      return;
    }

    state = AsyncData(
      _buildState(
        isRefreshing: true,
        isLoadingMore: false,
        errorMessage: current.errorMessage,
      ),
    );

    try {
      await Future.wait([
        ref.read(groupListV2ViewModelProvider.notifier).refreshGroups(),
        ref.read(threadListV2ViewModelProvider.notifier).refreshThreads(),
      ]);
      state = AsyncData(
        _buildState(
          isRefreshing: false,
          isLoadingMore: false,
          errorMessage: null,
        ),
      );
    } catch (error) {
      state = AsyncData(
        _buildState(
          isRefreshing: false,
          isLoadingMore: false,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> loadMoreAll() async {
    final current = state.value;
    if (current == null || current.isRefreshing || current.isLoadingMore) {
      return;
    }
    if (!current.groupsHasMore && !current.threadsHasMore) {
      return;
    }

    state = AsyncData(
      _buildState(
        isRefreshing: current.isRefreshing,
        isLoadingMore: true,
        errorMessage: current.errorMessage,
      ),
    );

    try {
      await Future.wait([
        if (current.groupsHasMore)
          ref.read(groupListV2ViewModelProvider.notifier).loadMoreGroups(),
        if (current.threadsHasMore)
          ref.read(threadListV2ViewModelProvider.notifier).loadMoreThreads(),
      ]);
    } finally {
      final latest = state.value;
      state = AsyncData(
        _buildState(
          isRefreshing: latest?.isRefreshing ?? false,
          isLoadingMore: false,
          errorMessage: latest?.errorMessage,
        ),
      );
    }
  }
}

final allListV2ViewModelProvider =
    AsyncNotifierProvider<AllListV2ViewModel, AllListV2ViewState>(
      AllListV2ViewModel.new,
    );
