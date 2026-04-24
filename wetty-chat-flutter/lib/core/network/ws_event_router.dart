import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import '../../features/conversation/shared/data/conversation_realtime_message_applier.dart';
import '../../features/chat_list_v2/application/group_list_v2_store.dart';
import '../../features/chat_list_v2/application/thread_list_v2_store.dart';
import '../../features/shared/application/chat_inbox_reconciler.dart';
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
  bool isReconcilingListProjection = false;

  void reconcileListProjectionIfNeeded(bool shouldReconcile) {
    if (!shouldReconcile || isReconcilingListProjection) {
      return;
    }

    isReconcilingListProjection = true;
    unawaited(
      ref
          .read(chatInboxReconcilerProvider)
          .reconcile()
          .whenComplete(() => isReconcilingListProjection = false),
    );
  }

  void applyListProjectionEvent(ApiWsEvent event) {
    switch (event) {
      case MessageCreatedWsEvent():
      case MessageUpdatedWsEvent():
      case MessageDeletedWsEvent():
        final shouldReconcileGroups = ref
            .read(groupListV2StoreProvider.notifier)
            .applyRealtimeEvent(event);
        final shouldReconcileThreads = ref
            .read(threadListV2StoreProvider.notifier)
            .applyRealtimeEvent(event);
        ref.read(unreadBadgeProvider.notifier).scheduleReconcile();
        reconcileListProjectionIfNeeded(
          shouldReconcileGroups || shouldReconcileThreads,
        );
        return;
      case ThreadUpdatedWsEvent():
        final shouldReconcileThreads = ref
            .read(threadListV2StoreProvider.notifier)
            .applyRealtimeEvent(event);
        reconcileListProjectionIfNeeded(shouldReconcileThreads);
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
