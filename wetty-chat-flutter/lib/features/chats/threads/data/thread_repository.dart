import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/models/messages_api_models.dart';
import '../../../../core/api/models/websocket_api_models.dart';
import '../../../../core/network/websocket_service.dart';
import '../../../../core/notifications/unread_badge_provider.dart';
import '../../../../core/session/dev_session_store.dart';
import '../../models/message_api_mapper.dart';
import '../models/thread_api_mapper.dart';
import '../models/thread_models.dart';
import 'thread_api_service.dart';

typedef ThreadListState = ({
  List<ThreadListItem> threads,
  String? nextCursor,
  bool hasMore,
  int totalUnreadCount,
});

/// Source of truth for thread list data.
/// Manages pagination, unread count, and realtime row projections.
class ThreadListNotifier extends Notifier<ThreadListState> {
  bool _isUnknownRealtimeRefreshing = false;

  @override
  ThreadListState build() {
    ref.listen<AsyncValue<ApiWsEvent>>(wsEventsProvider, (_, next) {
      final event = next.value;
      if (event != null) {
        _applyRealtimeEvent(event);
      }
    });
    return (
      threads: const [],
      nextCursor: null,
      hasMore: false,
      totalUnreadCount: 0,
    );
  }

  ThreadApiService get _service => ref.read(threadApiServiceProvider);

  /// Load the first page of threads.
  Future<void> loadThreads({int limit = 20}) async {
    final res = await _service.fetchThreads(limit: limit);
    final threads = res.threads.map((thread) => thread.toDomain()).toList();

    // Also fetch unread count alongside the initial load.
    final unreadRes = await _service.fetchUnreadThreadCount();

    state = (
      threads: threads,
      nextCursor: res.nextCursor,
      hasMore: res.nextCursor != null && res.nextCursor!.isNotEmpty,
      totalUnreadCount: unreadRes.unreadThreadCount,
    );
    ref
        .read(unreadBadgeProvider.notifier)
        .replaceThreadUnreadTotal(unreadRes.unreadThreadCount);
  }

  /// Load more threads (next page) using cursor-based pagination.
  Future<void> loadMoreThreads({int limit = 20}) async {
    if (!state.hasMore || state.nextCursor == null) return;
    final res = await _service.fetchThreads(
      limit: limit,
      before: state.nextCursor,
    );
    final existingIds = state.threads.map((t) => t.threadRootId).toSet();
    final newThreads = res.threads
        .map((thread) => thread.toDomain())
        .where((t) => !existingIds.contains(t.threadRootId))
        .toList();
    state = (
      threads: [...state.threads, ...newThreads],
      nextCursor: res.nextCursor,
      hasMore: res.nextCursor != null && res.nextCursor!.isNotEmpty,
      totalUnreadCount: state.totalUnreadCount,
    );
  }

  /// Reload threads from scratch.
  Future<void> refreshThreads({int? limit}) async {
    final targetLimit =
        limit ?? (state.threads.isEmpty ? 20 : state.threads.length);
    await loadThreads(limit: targetLimit);
  }

  void markThreadRead({required int threadRootId, required int messageId}) {
    final index = state.threads.indexWhere(
      (thread) => thread.threadRootId == threadRootId,
    );
    if (index < 0) {
      return;
    }

    final previous = state.threads[index];
    if (previous.unreadCount == 0) {
      return;
    }

    final threads = [...state.threads];
    threads[index] = previous.copyWith(unreadCount: 0);
    final nextUnread = state.totalUnreadCount - previous.unreadCount;
    state = (
      threads: threads,
      nextCursor: state.nextCursor,
      hasMore: state.hasMore,
      totalUnreadCount: nextUnread < 0 ? 0 : nextUnread,
    );
    ref
        .read(unreadBadgeProvider.notifier)
        .applyThreadUnreadDelta(-previous.unreadCount);
    ref.read(unreadBadgeProvider.notifier).scheduleReconcile();
  }

  void _applyRealtimeEvent(ApiWsEvent event) {
    switch (event) {
      case MessageCreatedWsEvent(:final payload):
        applyRealtimeCreated(payload);
        return;
      case MessageUpdatedWsEvent(:final payload):
        applyRealtimeUpdated(payload);
        return;
      case MessageDeletedWsEvent(:final payload):
        applyRealtimeDeleted(payload);
        return;
      case ThreadUpdatedWsEvent(:final payload):
        applyThreadUpdated(payload);
        return;
      default:
        return;
    }
  }

  void applyRealtimeCreated(MessageItemDto payload) {
    final threadRootId = payload.replyRootId;
    if (threadRootId == null) {
      return;
    }

    final index = _indexOfThread(threadRootId);
    if (index < 0) {
      unawaited(_refreshForUnknownRealtimeThread());
      return;
    }

    final previous = state.threads[index];
    final alreadyProjected =
        previous.lastReply?.messageId == payload.id ||
        (payload.clientGeneratedId.isNotEmpty &&
            previous.lastReply?.clientGeneratedId == payload.clientGeneratedId);
    final shouldIncrementUnread =
        !payload.isDeleted && payload.sender.uid != _currentUserId;
    final updated = previous.copyWith(
      lastReply: _toReplyPreview(payload),
      lastReplyAt: alreadyProjected
          ? (payload.createdAt ?? previous.lastReplyAt)
          : previous.lastReplyAt,
      replyCount: previous.replyCount,
      unreadCount: shouldIncrementUnread
          ? previous.unreadCount + 1
          : previous.unreadCount,
    );
    _patchThreadAt(index, updated);
    if (!alreadyProjected && payload.createdAt != null) {
      // Keep the row feeling realtime even before the matching threadUpdate arrives.
      _moveThreadToTop(index, updated);
    }
    if (shouldIncrementUnread) {
      _replaceState(totalUnreadCount: state.totalUnreadCount + 1);
      ref.read(unreadBadgeProvider.notifier).applyThreadUnreadDelta(1);
    }
  }

  void applyRealtimeUpdated(MessageItemDto payload) {
    if (payload.replyRootId == null) {
      _applyRootPatched(payload);
      return;
    }

    final index = _indexOfThread(payload.replyRootId!);
    if (index < 0) {
      unawaited(_refreshForUnknownRealtimeThread());
      return;
    }

    final previous = state.threads[index];
    if (!_matchesLastReply(previous.lastReply, payload)) {
      return;
    }

    _patchThreadAt(
      index,
      previous.copyWith(lastReply: _toReplyPreview(payload)),
    );
  }

  void applyRealtimeDeleted(MessageItemDto payload) {
    if (payload.replyRootId == null) {
      _applyRootPatched(payload);
      return;
    }

    final index = _indexOfThread(payload.replyRootId!);
    if (index < 0) {
      unawaited(_refreshForUnknownRealtimeThread());
      return;
    }

    final previous = state.threads[index];
    if (!_matchesLastReply(previous.lastReply, payload)) {
      return;
    }

    _patchThreadAt(
      index,
      previous.copyWith(lastReply: _toReplyPreview(payload)),
    );
  }

  void applyThreadUpdated(ThreadUpdatePayloadDto payload) {
    final index = _indexOfThread(payload.threadRootId);
    if (index < 0) {
      unawaited(_refreshForUnknownRealtimeThread());
      return;
    }

    final previous = state.threads[index];
    final updated = previous.copyWith(
      replyCount: payload.replyCount,
      lastReplyAt: payload.lastReplyAt,
    );
    _moveThreadToTop(index, updated);
  }

  int get _currentUserId => ref.read(authSessionProvider).currentUserId;

  int _indexOfThread(int threadRootId) {
    return state.threads.indexWhere(
      (thread) => thread.threadRootId == threadRootId,
    );
  }

  ThreadReplyPreview _toReplyPreview(MessageItemDto payload) {
    return ThreadReplyPreview(
      messageId: payload.id,
      clientGeneratedId: payload.clientGeneratedId.isEmpty
          ? null
          : payload.clientGeneratedId,
      sender: ThreadParticipant(
        uid: payload.sender.uid,
        name: payload.sender.name,
        avatarUrl: payload.sender.avatarUrl,
      ),
      message: payload.message,
      messageType: payload.messageType,
      stickerEmoji: payload.sticker?.emoji,
      firstAttachmentKind: payload.attachments.isNotEmpty
          ? payload.attachments.first.kind
          : null,
      isDeleted: payload.isDeleted,
      mentions: payload.mentions.map((mention) => mention.toDomain()).toList(),
    );
  }

  bool _matchesLastReply(ThreadReplyPreview? preview, MessageItemDto payload) {
    if (preview == null) {
      return false;
    }
    if (preview.messageId != null) {
      return preview.messageId == payload.id;
    }
    final clientGeneratedId = preview.clientGeneratedId;
    return clientGeneratedId != null &&
        clientGeneratedId.isNotEmpty &&
        clientGeneratedId == payload.clientGeneratedId;
  }

  void _applyRootPatched(MessageItemDto payload) {
    final index = _indexOfThread(payload.id);
    if (index < 0) {
      return;
    }

    if (payload.isDeleted) {
      _removeThreadAt(index);
      return;
    }

    final previous = state.threads[index];
    _patchThreadAt(
      index,
      previous.copyWith(threadRootMessage: payload.toDomain()),
    );
  }

  void _moveThreadToTop(int index, ThreadListItem updated) {
    final threads = [...state.threads]..removeAt(index);
    threads.insert(0, updated);
    _replaceState(threads: threads);
  }

  void _patchThreadAt(int index, ThreadListItem updated) {
    final threads = [...state.threads];
    threads[index] = updated;
    _replaceState(threads: threads);
  }

  void _removeThreadAt(int index) {
    final removed = state.threads[index];
    final threads = [...state.threads]..removeAt(index);
    final totalUnreadCount = state.totalUnreadCount - removed.unreadCount;
    _replaceState(
      threads: threads,
      totalUnreadCount: totalUnreadCount < 0 ? 0 : totalUnreadCount,
    );
    ref
        .read(unreadBadgeProvider.notifier)
        .applyThreadUnreadDelta(-removed.unreadCount);
  }

  void _replaceState({
    List<ThreadListItem>? threads,
    String? nextCursor,
    bool? hasMore,
    int? totalUnreadCount,
  }) {
    state = (
      threads: threads ?? state.threads,
      nextCursor: nextCursor ?? state.nextCursor,
      hasMore: hasMore ?? state.hasMore,
      totalUnreadCount: totalUnreadCount ?? state.totalUnreadCount,
    );
  }

  Future<void> _refreshForUnknownRealtimeThread() async {
    if (_isUnknownRealtimeRefreshing) {
      return;
    }

    _isUnknownRealtimeRefreshing = true;
    try {
      await refreshThreads();
    } catch (_) {
      // Ignore websocket refresh failures and rely on the next manual refresh.
    } finally {
      _isUnknownRealtimeRefreshing = false;
    }
  }
}

final threadListStateProvider =
    NotifierProvider<ThreadListNotifier, ThreadListState>(
      ThreadListNotifier.new,
    );
