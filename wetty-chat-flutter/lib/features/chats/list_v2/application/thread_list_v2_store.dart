import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../threads/models/thread_models.dart';

typedef ThreadListV2StoreState = ({
  List<ThreadListItem> threads,
  String? nextCursor,
  bool hasMore,
  int totalUnreadCount,
});

typedef ThreadListV2Identity = ({String chatId, String threadRootId});

class ThreadListV2Store extends Notifier<ThreadListV2StoreState> {
  @override
  ThreadListV2StoreState build() {
    return (
      threads: const [],
      nextCursor: null,
      hasMore: false,
      totalUnreadCount: 0,
    );
  }

  void replacePage({
    required List<ThreadListItem> threads,
    String? nextCursor,
    required int totalUnreadCount,
  }) {
    state = (
      threads: threads,
      nextCursor: nextCursor,
      hasMore: nextCursor != null && nextCursor.isNotEmpty,
      totalUnreadCount: totalUnreadCount,
    );
  }

  void appendPage({required List<ThreadListItem> threads, String? nextCursor}) {
    final existingKeys = state.threads
        .map((thread) => '${thread.chatId}:${thread.threadRootId}')
        .toSet();
    final appended = threads
        .where(
          (thread) =>
              !existingKeys.contains('${thread.chatId}:${thread.threadRootId}'),
        )
        .toList(growable: false);

    state = (
      threads: [...state.threads, ...appended],
      nextCursor: nextCursor,
      hasMore: nextCursor != null && nextCursor.isNotEmpty,
      totalUnreadCount: state.totalUnreadCount,
    );
  }
}

final threadListV2StoreProvider =
    NotifierProvider<ThreadListV2Store, ThreadListV2StoreState>(
      ThreadListV2Store.new,
    );

final threadByIdProvider =
    Provider.family<ThreadListItem?, ThreadListV2Identity>((ref, identity) {
      return ref.watch(
        threadListV2StoreProvider.select(
          (state) => state.threads
              .where(
                (thread) =>
                    thread.chatId == identity.chatId &&
                    thread.threadRootId.toString() == identity.threadRootId,
              )
              .firstOrNull,
        ),
      );
    });
