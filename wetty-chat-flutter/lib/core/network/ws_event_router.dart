import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import '../../features/chats/conversation_v2/application/conversation_timeline_v2_realtime_applier.dart';
import '../../features/chats/list/data/chat_repository.dart';
import '../../features/chats/list_v2/application/group_list_v2_store.dart';
import '../../features/chats/threads/data/thread_repository.dart';
import '../../features/stickers/data/sticker_pack_order_store.dart';
import '../api/models/websocket_api_models.dart';
import '../notifications/unread_badge_provider.dart';
import 'websocket_service.dart';

class _WsEventDeduplicator {
  String? _lastEventKey;

  bool shouldHandle(ApiWsEvent event) {
    final eventKey = switch (event) {
      MessageCreatedWsEvent(:final payload) => [
        'messageCreated',
        payload.id,
        payload.chatId,
        payload.replyRootId,
        payload.clientGeneratedId,
        payload.createdAt?.millisecondsSinceEpoch,
        payload.isDeleted,
      ].join(':'),
      MessageUpdatedWsEvent(:final payload) => [
        'messageUpdated',
        payload.id,
        payload.chatId,
        payload.replyRootId,
        payload.clientGeneratedId,
        payload.createdAt?.millisecondsSinceEpoch,
        payload.isDeleted,
      ].join(':'),
      MessageDeletedWsEvent(:final payload) => [
        'messageDeleted',
        payload.id,
        payload.chatId,
        payload.replyRootId,
        payload.clientGeneratedId,
        payload.createdAt?.millisecondsSinceEpoch,
        payload.isDeleted,
      ].join(':'),
      ReactionUpdatedWsEvent(:final payload) => [
        'reactionUpdated',
        payload.chatId,
        payload.messageId,
        payload.reactions
            .map((reaction) => '${reaction.emoji}:${reaction.count}')
            .join(','),
      ].join(':'),
      ThreadUpdatedWsEvent(:final payload) => [
        'threadUpdated',
        payload.chatId,
        payload.threadRootId,
        payload.lastReplyAt.millisecondsSinceEpoch,
        payload.replyCount,
      ].join(':'),
      StickerPackOrderUpdatedWsEvent(:final payload) => [
        'stickerPackOrderUpdated',
        payload.order
            .map((item) => '${item.stickerPackId}:${item.lastUsedOn}')
            .join(','),
      ].join(':'),
      PongWsEvent() => 'pong',
    };

    if (_lastEventKey == eventKey) {
      return false;
    }
    _lastEventKey = eventKey;
    return true;
  }
}

final _wsEventDeduplicatorProvider = Provider<_WsEventDeduplicator>((ref) {
  return _WsEventDeduplicator();
});

/// Centralizes websocket event fan-out to app subsystems.
final wsEventRouterProvider = Provider<void>((ref) {
  StreamSubscription<ApiWsEvent>? subscription;

  void applyListProjectionEvent(ApiWsEvent event) {
    switch (event) {
      case MessageCreatedWsEvent():
      case MessageUpdatedWsEvent():
      case MessageDeletedWsEvent():
        ref.read(groupListV2StoreProvider.notifier).applyRealtimeEvent(event);
        ref.read(chatListStateProvider.notifier).applyRealtimeEvent(event);
        ref.read(threadListStateProvider.notifier).applyRealtimeEvent(event);
        ref.read(unreadBadgeProvider.notifier).scheduleReconcile();
        return;
      case ThreadUpdatedWsEvent():
        ref.read(threadListStateProvider.notifier).applyRealtimeEvent(event);
        return;
      case ReactionUpdatedWsEvent():
        return;
      case StickerPackOrderUpdatedWsEvent():
        return;
      case PongWsEvent():
        return;
    }
  }

  void applyAuxiliaryEvent(ApiWsEvent event) {
    switch (event) {
      case StickerPackOrderUpdatedWsEvent(:final payload):
        final order = payload.order
            .map(
              (dto) => StickerPackOrderItem(
                stickerPackId: dto.stickerPackId,
                lastUsedOn: dto.lastUsedOn,
              ),
            )
            .toList(growable: false);
        ref.read(stickerPackOrderProvider.notifier).replaceOrderFromWs(order);
        return;
      case MessageCreatedWsEvent():
      case MessageUpdatedWsEvent():
      case MessageDeletedWsEvent():
      case ReactionUpdatedWsEvent():
      case ThreadUpdatedWsEvent():
      case PongWsEvent():
        return;
    }
  }

  void bind(WebSocketService service) {
    subscription?.cancel();
    subscription = service.events.listen((event) {
      if (!ref.read(_wsEventDeduplicatorProvider).shouldHandle(event)) {
        return;
      }
      ref.read(conversationTimelineV2RealtimeApplierProvider).apply(event);
      applyListProjectionEvent(event);
      applyAuxiliaryEvent(event);
    });
  }

  ref.listen<WebSocketService>(webSocketProvider, (previous, next) {
    if (!identical(previous, next)) {
      bind(next);
    }
  }, fireImmediately: true);
  ref.onDispose(() async => subscription?.cancel());
});
