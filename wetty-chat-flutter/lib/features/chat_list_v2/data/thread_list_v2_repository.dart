import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/unread_badge_provider.dart';
import '../../chats/threads/data/thread_api_service.dart';
import '../../chats/threads/models/thread_api_models.dart';
import '../../chats/threads/models/thread_api_mapper.dart';
import '../application/thread_list_v2_store.dart';

class ThreadListV2Repository {
  ThreadListV2Repository(this.ref);

  final Ref ref;

  Future<void> loadThreads({int limit = 20}) async {
    final results = await Future.wait([
      ref.read(threadApiServiceProvider).fetchThreads(limit: limit),
      ref.read(threadApiServiceProvider).fetchUnreadThreadCount(),
    ]);
    final response = results[0] as ListThreadsResponseDto;
    final unreadResponse = results[1] as UnreadThreadCountResponseDto;
    final threads = response.threads
        .map((thread) => thread.toDomain())
        .toList(growable: false);
    ref
        .read(threadListV2StoreProvider.notifier)
        .replacePage(
          threads: threads,
          nextCursor: response.nextCursor,
          totalUnreadCount: unreadResponse.unreadThreadCount,
        );
    ref
        .read(unreadBadgeProvider.notifier)
        .replaceThreadUnreadTotal(unreadResponse.unreadThreadCount);
  }

  Future<void> loadMoreThreads({int limit = 20}) async {
    final current = ref.read(threadListV2StoreProvider);
    if (!current.hasMore || current.nextCursor == null) {
      return;
    }

    final response = await ref
        .read(threadApiServiceProvider)
        .fetchThreads(limit: limit, before: current.nextCursor);
    final threads = response.threads
        .map((thread) => thread.toDomain())
        .toList(growable: false);
    ref
        .read(threadListV2StoreProvider.notifier)
        .appendPage(threads: threads, nextCursor: response.nextCursor);
  }
}

final threadListV2RepositoryProvider = Provider<ThreadListV2Repository>((ref) {
  return ThreadListV2Repository(ref);
});
