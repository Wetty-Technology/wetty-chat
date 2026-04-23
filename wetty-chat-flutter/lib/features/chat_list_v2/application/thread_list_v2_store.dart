import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/models/messages_api_models.dart';
import '../../../core/api/models/websocket_api_models.dart';
import '../../../core/notifications/unread_badge_provider.dart';
import '../../../core/session/dev_session_store.dart';
import '../../chats/list_projection/domain/list_projection_helpers.dart';
import '../../chats/models/message_api_mapper.dart';
import '../../chats/threads/models/thread_models.dart';

typedef ThreadListV2StoreState = ({
  List<ThreadListItem> threads,
  String? nextCursor,
  bool hasMore,
  int totalUnreadCount,
});

typedef ThreadListV2Identity = ({String chatId, String threadRootId});

class ThreadListV2Store extends Notifier<ThreadListV2StoreState> {
  bool _isUnknownRealtimeRefreshing = false;

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

  void applyRealtimeEvent(ApiWsEvent event) {
    switch (event) {
      case MessageCreatedWsEvent(:final payload):
        _applyRealtimeCreated(payload);
        return;
      case MessageUpdatedWsEvent(:final payload):
        _applyRealtimeUpdated(payload);
        return;
      case MessageDeletedWsEvent(:final payload):
        _applyRealtimeDeleted(payload);
        return;
      case ThreadUpdatedWsEvent():
        _refreshForUnknownRealtimeThread();
        return;
      default:
        return;
    }
  }

  void _applyRealtimeCreated(MessageItemDto payload) {
    final threadRootId = payload.replyRootId;
    if (threadRootId == null || !isEligibleThreadPreviewPayload(payload)) {
      return;
    }

    final index = _indexOfThread(threadRootId);
    if (index < 0) {
      _refreshForUnknownRealtimeThread();
      return;
    }

    final previous = state.threads[index];
    final alreadyProjected = matchesThreadPreview(previous.lastReply, payload);
    final shouldIncrementUnread =
        !alreadyProjected &&
        !payload.isDeleted &&
        payload.sender.uid != _currentUserId;
    final updated = previous.copyWith(
      lastReply: _toReplyPreview(payload),
      lastReplyAt: payload.createdAt ?? previous.lastReplyAt,
      replyCount: alreadyProjected
          ? previous.replyCount
          : previous.replyCount + 1,
      unreadCount: shouldIncrementUnread
          ? previous.unreadCount + 1
          : previous.unreadCount,
    );
    _replaceState(
      threads: reinsertThreadByActivity(state.threads, index, updated),
    );
    if (shouldIncrementUnread) {
      _replaceState(totalUnreadCount: state.totalUnreadCount + 1);
      ref.read(unreadBadgeProvider.notifier).applyThreadUnreadDelta(1);
    }
  }

  void _applyRealtimeUpdated(MessageItemDto payload) {
    if (payload.replyRootId == null) {
      _applyRootPatched(payload);
      return;
    }

    final index = _indexOfThread(payload.replyRootId!);
    if (index < 0) {
      _refreshForUnknownRealtimeThread();
      return;
    }

    final previous = state.threads[index];
    if (!matchesThreadPreview(previous.lastReply, payload)) {
      return;
    }

    _replaceState(
      threads: replaceThreadAt(
        state.threads,
        index,
        previous.copyWith(lastReply: _toReplyPreview(payload)),
      ),
    );
  }

  void _applyRealtimeDeleted(MessageItemDto payload) {
    if (payload.replyRootId == null) {
      _applyRootPatched(payload);
      return;
    }

    final index = _indexOfThread(payload.replyRootId!);
    if (index < 0) {
      _refreshForUnknownRealtimeThread();
      return;
    }

    final previous = state.threads[index];
    final isCurrentPreview = matchesThreadPreview(previous.lastReply, payload);
    if (isCurrentPreview) {
      _refreshForUnknownRealtimeThread();
      return;
    }

    final updated = previous.copyWith(
      replyCount: previous.replyCount > 0 ? previous.replyCount - 1 : 0,
    );
    _replaceState(threads: replaceThreadAt(state.threads, index, updated));
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

  void _applyRootPatched(MessageItemDto payload) {
    final index = _indexOfThread(payload.id);
    if (index < 0) {
      return;
    }

    final previous = state.threads[index];
    _replaceState(
      threads: replaceThreadAt(
        state.threads,
        index,
        previous.copyWith(threadRootMessage: payload.toDomain()),
      ),
    );
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

  void _refreshForUnknownRealtimeThread() {
    if (_isUnknownRealtimeRefreshing) {
      return;
    }

    _isUnknownRealtimeRefreshing = true;
    Future<void>.microtask(() {
      // TODO(codex): Reconcile the v2 threads list from the backend when a
      // realtime event references a thread or preview slice we cannot update
      // precisely from local state.
      _isUnknownRealtimeRefreshing = false;
    });
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
