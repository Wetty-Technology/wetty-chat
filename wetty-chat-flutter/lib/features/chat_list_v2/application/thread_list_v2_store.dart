import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/models/messages_api_models.dart';
import '../../../core/api/models/websocket_api_models.dart';
import '../../../core/notifications/unread_badge_provider.dart';
import '../../../core/session/dev_session_store.dart';
import '../../chats/list_projection/domain/list_projection_helpers.dart';
import '../../chats/models/message_models.dart';
import '../../chats/threads/models/thread_models.dart';

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

  bool applyRealtimeEvent(ApiWsEvent event) {
    switch (event) {
      case MessageCreatedWsEvent(:final payload):
        return _applyRealtimeCreated(payload);
      case MessageUpdatedWsEvent(:final payload):
        return _applyRealtimeUpdated(payload);
      case MessageDeletedWsEvent(:final payload):
        return _applyRealtimeDeleted(payload);
      case ThreadUpdatedWsEvent():
        return true;
      default:
        return false;
    }
  }

  bool _applyRealtimeCreated(MessageItemDto payload) {
    final threadRootId = payload.replyRootId;
    if (threadRootId == null || !isEligibleThreadPreviewPayload(payload)) {
      return false;
    }

    final index = _indexOfThread(threadRootId);
    if (index < 0) {
      return true;
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
    return false;
  }

  bool _applyRealtimeUpdated(MessageItemDto payload) {
    if (payload.replyRootId == null) {
      return _applyRootPatched(payload);
    }

    final index = _indexOfThread(payload.replyRootId!);
    if (index < 0) {
      return true;
    }

    final previous = state.threads[index];
    if (!matchesThreadPreview(previous.lastReply, payload)) {
      return false;
    }

    _replaceState(
      threads: replaceThreadAt(
        state.threads,
        index,
        previous.copyWith(lastReply: _toReplyPreview(payload)),
      ),
    );
    return false;
  }

  bool _applyRealtimeDeleted(MessageItemDto payload) {
    if (payload.replyRootId == null) {
      return _applyRootPatched(payload);
    }

    final index = _indexOfThread(payload.replyRootId!);
    if (index < 0) {
      return true;
    }

    final previous = state.threads[index];
    final isCurrentPreview = matchesThreadPreview(previous.lastReply, payload);
    if (isCurrentPreview) {
      return true;
    }

    final updated = previous.copyWith(
      replyCount: previous.replyCount > 0 ? previous.replyCount - 1 : 0,
    );
    _replaceState(threads: replaceThreadAt(state.threads, index, updated));
    return false;
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
      sender: Sender.fromDto(payload.sender),
      message: payload.message,
      messageType: payload.messageType,
      stickerEmoji: payload.sticker?.emoji,
      firstAttachmentKind: payload.attachments.isNotEmpty
          ? payload.attachments.first.kind
          : null,
      isDeleted: payload.isDeleted,
      mentions: payload.mentions.map(MentionInfo.fromDto).toList(),
    );
  }

  bool _applyRootPatched(MessageItemDto payload) {
    final index = _indexOfThread(payload.id);
    if (index < 0) {
      return false;
    }

    final previous = state.threads[index];
    _replaceState(
      threads: replaceThreadAt(
        state.threads,
        index,
        previous.copyWith(threadRootMessage: MessageItem.fromDto(payload)),
      ),
    );
    return false;
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
