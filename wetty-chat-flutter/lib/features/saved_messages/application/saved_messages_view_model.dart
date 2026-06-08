import 'package:chahua/core/api/models/saved_messages_api_models.dart';
import 'package:chahua/core/api/services/saved_messages_api_service.dart';
import 'package:chahua/features/saved_messages/domain/saved_messages_scope.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const _sentinel = Object();

class SavedMessagesState {
  const SavedMessagesState({
    this.savedMessages = const <SavedMessageResponseDto>[],
    this.nextCursor,
    this.isLoadingMore = false,
    this.error,
    this.unsavingIds = const <int>{},
  });

  final List<SavedMessageResponseDto> savedMessages;
  final int? nextCursor;
  final bool isLoadingMore;
  final Object? error;
  final Set<int> unsavingIds;

  bool get hasMore => nextCursor != null;

  SavedMessagesState copyWith({
    List<SavedMessageResponseDto>? savedMessages,
    Object? nextCursor = _sentinel,
    bool? isLoadingMore,
    Object? error = _sentinel,
    Set<int>? unsavingIds,
  }) {
    return SavedMessagesState(
      savedMessages: savedMessages ?? this.savedMessages,
      nextCursor: identical(nextCursor, _sentinel)
          ? this.nextCursor
          : nextCursor as int?,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: identical(error, _sentinel) ? this.error : error,
      unsavingIds: unsavingIds ?? this.unsavingIds,
    );
  }
}

class SavedMessagesViewModel extends AsyncNotifier<SavedMessagesState> {
  SavedMessagesViewModel(this.scope);

  static const int pageSize = 25;

  final SavedMessagesScope scope;
  int _generation = 0;

  @override
  Future<SavedMessagesState> build() async {
    final response = await _list();
    return SavedMessagesState(
      savedMessages: response.savedMessages,
      nextCursor: response.nextCursor,
    );
  }

  Future<void> reload() async {
    final generation = ++_generation;
    state = const AsyncLoading<SavedMessagesState>();
    try {
      final response = await _list();
      if (generation != _generation) {
        return;
      }
      state = AsyncData(
        SavedMessagesState(
          savedMessages: response.savedMessages,
          nextCursor: response.nextCursor,
        ),
      );
    } catch (error, stackTrace) {
      if (generation != _generation) {
        return;
      }
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.isLoadingMore) {
      return;
    }

    final generation = _generation;
    state = AsyncData(current.copyWith(isLoadingMore: true, error: null));

    try {
      final response = await _list(before: current.nextCursor);
      if (generation != _generation) {
        return;
      }
      state = AsyncData(
        current.copyWith(
          savedMessages: [...current.savedMessages, ...response.savedMessages],
          nextCursor: response.nextCursor,
          isLoadingMore: false,
          error: null,
        ),
      );
    } catch (error) {
      if (generation != _generation) {
        return;
      }
      final latest = state.value ?? current;
      state = AsyncData(latest.copyWith(isLoadingMore: false, error: error));
    }
  }

  Future<void> unsave(int savedMessageId) async {
    final current = state.value;
    if (current == null || current.unsavingIds.contains(savedMessageId)) {
      return;
    }

    final optimisticMessages = [
      for (final saved in current.savedMessages)
        if (saved.id != savedMessageId) saved,
    ];
    state = AsyncData(
      current.copyWith(
        savedMessages: optimisticMessages,
        unsavingIds: {...current.unsavingIds, savedMessageId},
        error: null,
      ),
    );

    try {
      await ref
          .read(savedMessagesApiServiceProvider)
          .deleteSavedMessage(savedMessageId);
      final latest = state.value;
      if (latest == null) {
        return;
      }
      state = AsyncData(
        latest.copyWith(
          unsavingIds: {
            for (final id in latest.unsavingIds)
              if (id != savedMessageId) id,
          },
        ),
      );
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<ListSavedMessagesResponseDto> _list({int? before}) {
    final chatId = scope.chatId;
    final api = ref.read(savedMessagesApiServiceProvider);
    if (chatId == null) {
      return api.listSavedMessages(limit: pageSize, before: before);
    }
    return api.listChatSavedMessages(chatId, limit: pageSize, before: before);
  }
}

final savedMessagesViewModelProvider = AsyncNotifierProvider.autoDispose
    .family<SavedMessagesViewModel, SavedMessagesState, SavedMessagesScope>(
      SavedMessagesViewModel.new,
    );
