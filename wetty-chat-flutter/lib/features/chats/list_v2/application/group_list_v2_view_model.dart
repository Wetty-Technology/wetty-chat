import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/chat_models.dart';
import '../data/group_list_v2_repository.dart';
import 'group_list_v2_store.dart';

typedef GroupListV2ViewState = ({
  List<ChatListItem> groups,
  bool hasMore,
  bool isLoadingMore,
  bool isRefreshing,
  bool isLoading,
  String? errorMessage,
});

class GroupListV2ViewModel extends AsyncNotifier<GroupListV2ViewState> {
  @override
  Future<GroupListV2ViewState> build() async {
    ref.listen<GroupListV2StoreState>(groupListV2StoreProvider, (_, _) {
      _rebuildFromStore();
    });
    return _loadInitial();
  }

  Future<GroupListV2ViewState> _loadInitial() async {
    await ref.read(groupListV2RepositoryProvider).loadGroups();
    final storeState = ref.read(groupListV2StoreProvider);
    return (
      groups: storeState.groups,
      hasMore: storeState.hasMore,
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
    final storeState = ref.read(groupListV2StoreProvider);
    state = AsyncData((
      groups: storeState.groups,
      hasMore: storeState.hasMore,
      isLoadingMore: current.isLoadingMore,
      isRefreshing: current.isRefreshing,
      isLoading: false,
      errorMessage: current.errorMessage,
    ));
  }

  Future<void> loadMoreGroups() async {
    final current = state.value;
    if (current == null) {
      return;
    }
    if (!current.hasMore || current.isLoadingMore || current.groups.isEmpty) {
      return;
    }

    state = AsyncData((
      groups: current.groups,
      hasMore: current.hasMore,
      isLoadingMore: true,
      isRefreshing: current.isRefreshing,
      isLoading: false,
      errorMessage: current.errorMessage,
    ));
    try {
      await ref.read(groupListV2RepositoryProvider).loadMoreGroups();
    } catch (_) {
      // Silently fail pagination.
    } finally {
      final storeState = ref.read(groupListV2StoreProvider);
      final latest = state.value;
      if (latest != null) {
        state = AsyncData((
          groups: storeState.groups,
          hasMore: storeState.hasMore,
          isLoadingMore: false,
          isRefreshing: latest.isRefreshing,
          isLoading: false,
          errorMessage: latest.errorMessage,
        ));
      }
    }
  }

  Future<void> refreshGroups() async {
    final current = state.value;
    if (current == null) {
      return;
    }
    if (current.isLoadingMore || current.isRefreshing) {
      return;
    }

    state = AsyncData((
      groups: current.groups,
      hasMore: current.hasMore,
      isLoadingMore: current.isLoadingMore,
      isRefreshing: true,
      isLoading: false,
      errorMessage: current.errorMessage,
    ));
    try {
      final limit = current.groups.isEmpty ? 20 : current.groups.length;
      await ref.read(groupListV2RepositoryProvider).loadGroups(limit: limit);
      final storeState = ref.read(groupListV2StoreProvider);
      state = AsyncData((
        groups: storeState.groups,
        hasMore: storeState.hasMore,
        isLoadingMore: false,
        isRefreshing: false,
        isLoading: false,
        errorMessage: null,
      ));
    } catch (error) {
      final latest = state.value;
      if (latest != null) {
        state = AsyncData((
          groups: latest.groups,
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

final groupListV2ViewModelProvider =
    AsyncNotifierProvider<GroupListV2ViewModel, GroupListV2ViewState>(
      GroupListV2ViewModel.new,
    );
