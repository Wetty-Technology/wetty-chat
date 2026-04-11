import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/group_member_models.dart';
import '../data/group_member_repository.dart';

class GroupMembersViewState {
  const GroupMembersViewState({
    required this.members,
    required this.searchQuery,
    required this.searchMode,
    required this.canManageMembers,
    required this.isLoadingMore,
    this.nextCursor,
  });

  final List<GroupMember> members;
  final String searchQuery;
  final GroupMemberSearchMode searchMode;
  final bool canManageMembers;
  final bool isLoadingMore;
  final int? nextCursor;

  bool get hasMore => nextCursor != null;

  GroupMembersViewState copyWith({
    List<GroupMember>? members,
    String? searchQuery,
    GroupMemberSearchMode? searchMode,
    bool? canManageMembers,
    bool? isLoadingMore,
    Object? nextCursor = _sentinel,
  }) {
    return GroupMembersViewState(
      members: members ?? this.members,
      searchQuery: searchQuery ?? this.searchQuery,
      searchMode: searchMode ?? this.searchMode,
      canManageMembers: canManageMembers ?? this.canManageMembers,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      nextCursor: nextCursor == _sentinel
          ? this.nextCursor
          : nextCursor as int?,
    );
  }
}

const Object _sentinel = Object();

class GroupMembersViewModel extends AsyncNotifier<GroupMembersViewState> {
  final String arg;

  GroupMembersViewModel(this.arg);

  static const int _pageSize = 50;

  @override
  Future<GroupMembersViewState> build() async {
    return _loadMembers();
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _loadMembers();
    });
  }

  Future<void> updateSearchQuery(
    String query, {
    GroupMemberSearchMode mode = GroupMemberSearchMode.autocomplete,
  }) async {
    final normalizedQuery = query.trim();
    final current = state.value;
    if (current != null && current.searchQuery == normalizedQuery) {
      return;
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return _loadMembers(query: normalizedQuery, mode: mode);
    });
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) {
      return;
    }

    state = AsyncData(current.copyWith(isLoadingMore: true));
    try {
      final nextPage = await _fetchMembers(
        query: current.searchQuery,
        mode: current.searchMode,
        after: current.nextCursor,
      );
      state = AsyncData(
        current.copyWith(
          members: _mergeMembers(current.members, nextPage.members),
          canManageMembers: nextPage.canManageMembers,
          nextCursor: nextPage.nextCursor,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      final latest = state.value ?? current;
      state = AsyncData(latest.copyWith(isLoadingMore: false));
    }
  }

  Future<void> addMember(int userId) async {
    final current = state.value;
    final repository = ref.read(groupMemberRepositoryProvider);
    await repository.addMember(arg, userId: userId);
    await _reloadKeepingState(current);
  }

  Future<void> removeMember(int userId) async {
    final current = state.value;
    final repository = ref.read(groupMemberRepositoryProvider);
    await repository.removeMember(arg, userId: userId);
    await _reloadKeepingState(current);
  }

  Future<void> updateMemberRole(int userId, {required String role}) async {
    final current = state.value;
    final repository = ref.read(groupMemberRepositoryProvider);
    await repository.updateMemberRole(arg, userId: userId, role: role);
    await _reloadKeepingState(current);
  }

  Future<GroupMembersViewState> _loadMembers({
    String query = '',
    GroupMemberSearchMode mode = GroupMemberSearchMode.autocomplete,
  }) async {
    final page = await _fetchMembers(query: query, mode: mode);
    return GroupMembersViewState(
      members: page.members,
      searchQuery: query,
      searchMode: mode,
      canManageMembers: page.canManageMembers,
      isLoadingMore: false,
      nextCursor: page.nextCursor,
    );
  }

  Future<GroupMembersPage> _fetchMembers({
    required String query,
    required GroupMemberSearchMode mode,
    int? after,
  }) async {
    final repository = ref.read(groupMemberRepositoryProvider);
    return repository.fetchMembers(
      arg,
      limit: _pageSize,
      after: after,
      query: query,
      searchMode: query.isEmpty ? null : mode,
    );
  }

  Future<void> _reloadKeepingState(GroupMembersViewState? previous) async {
    try {
      final nextState = await _loadMembers(
        query: previous?.searchQuery ?? '',
        mode: previous?.searchMode ?? GroupMemberSearchMode.autocomplete,
      );
      state = AsyncData(nextState);
    } catch (error, stackTrace) {
      if (previous != null) {
        state = AsyncData(previous);
      } else {
        state = AsyncError(error, stackTrace);
      }
      rethrow;
    }
  }

  List<GroupMember> _mergeMembers(
    List<GroupMember> existing,
    List<GroupMember> incoming,
  ) {
    final seen = existing.map((member) => member.uid).toSet();
    final merged = [...existing];
    for (final member in incoming) {
      if (seen.add(member.uid)) {
        merged.add(member);
      }
    }
    return merged;
  }
}

final groupMembersViewModelProvider =
    AsyncNotifierProvider.family<
      GroupMembersViewModel,
      GroupMembersViewState,
      String
    >(GroupMembersViewModel.new);
