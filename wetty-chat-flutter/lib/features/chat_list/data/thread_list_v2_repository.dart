import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chahua/core/api/models/thread_api_models.dart';
import 'package:chahua/core/api/services/thread_api_service.dart';
import 'package:chahua/core/notifications/unread_badge_provider.dart';

import '../model/thread_list_item.dart';
import '../application/thread_list_v2_store.dart';

class ThreadListV2Repository {
  ThreadListV2Repository(this.ref);

  final Ref ref;

  Future<void> loadThreads({int limit = 20}) async {
    debugPrint('loadThreads');
    final results = await Future.wait([
      ref
          .read(threadApiServiceProvider)
          .fetchThreads(limit: limit, archived: false),
      ref.read(threadApiServiceProvider).fetchUnreadThreadCount(),
    ]);
    final response = results[0] as ListThreadsResponseDto;
    final unreadResponse = results[1] as UnreadThreadCountResponseDto;
    final threads = response.threads
        .map(ThreadListItem.fromDto)
        .toList(growable: false);
    ref
        .read(threadListV2StoreProvider.notifier)
        .replaceActivePage(threads: threads, nextCursor: response.nextCursor);
    ref.read(threadListV2StoreProvider.notifier).replaceUnreadTotals((
      activeThreadCount: unreadResponse.unreadThreadCount,
      archivedThreadCount: unreadResponse.archivedUnreadThreadCount,
      activeMessageCount: unreadResponse.unreadMessageCount,
      archivedMessageCount: unreadResponse.archivedUnreadMessageCount,
    ));
    ref
        .read(unreadBadgeProvider.notifier)
        .replaceThreadUnreadTotal(unreadResponse.unreadThreadCount);
  }

  Future<void> probeArchivedThreads() async {
    final response = await ref
        .read(threadApiServiceProvider)
        .fetchThreads(limit: 1, archived: true);
    ref
        .read(threadListV2StoreProvider.notifier)
        .replaceHasArchivedThreads(response.threads.isNotEmpty);
  }

  Future<void> loadMoreThreads({int limit = 20}) async {
    final current = ref.read(threadListV2StoreProvider).active;
    if (!current.hasMore || current.nextCursor == null) {
      return;
    }

    final response = await ref
        .read(threadApiServiceProvider)
        .fetchThreads(
          limit: limit,
          before: current.nextCursor,
          archived: false,
        );
    final threads = response.threads
        .map(ThreadListItem.fromDto)
        .toList(growable: false);
    ref
        .read(threadListV2StoreProvider.notifier)
        .appendActivePage(threads: threads, nextCursor: response.nextCursor);
  }

  Future<void> loadArchivedThreads({int limit = 20}) async {
    debugPrint('loadArchivedThreads');
    final response = await ref
        .read(threadApiServiceProvider)
        .fetchThreads(limit: limit, archived: true);
    final threads = response.threads
        .map(ThreadListItem.fromDto)
        .toList(growable: false);
    ref
        .read(threadListV2StoreProvider.notifier)
        .replaceArchivedPage(threads: threads, nextCursor: response.nextCursor);
  }

  Future<void> loadMoreArchivedThreads({int limit = 20}) async {
    final current = ref.read(threadListV2StoreProvider).archived;
    if (!current.hasMore || current.nextCursor == null) {
      return;
    }

    final response = await ref
        .read(threadApiServiceProvider)
        .fetchThreads(limit: limit, before: current.nextCursor, archived: true);
    final threads = response.threads
        .map(ThreadListItem.fromDto)
        .toList(growable: false);
    ref
        .read(threadListV2StoreProvider.notifier)
        .appendArchivedPage(threads: threads, nextCursor: response.nextCursor);
  }

  Future<void> archiveThread(ThreadListItem thread) {
    return ref
        .read(threadApiServiceProvider)
        .archiveThread(thread.chatId, thread.threadRootId);
  }

  Future<void> unarchiveThread(ThreadListItem thread) {
    return ref
        .read(threadApiServiceProvider)
        .unarchiveThread(thread.chatId, thread.threadRootId);
  }
}

final threadListV2RepositoryProvider = Provider<ThreadListV2Repository>((ref) {
  return ThreadListV2Repository(ref);
});
