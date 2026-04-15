import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';

import '../../features/chats/conversation/data/conversation_repository.dart';
import '../../features/chats/conversation/domain/conversation_scope.dart';
import '../../features/chats/conversation/application/conversation_realtime_registry.dart';
import '../../features/chats/list/data/chat_repository.dart';
import '../../features/chats/message_domain/domain/message_domain.dart';
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

  void applyConversationCacheEvent(ApiWsEvent event) {
    switch (event) {
      case MessageCreatedWsEvent(:final payload):
      case MessageUpdatedWsEvent(:final payload):
      case MessageDeletedWsEvent(:final payload):
        final store = ref.read(messageDomainStoreProvider);
        final scopes = <ConversationScope>{
          ...store.cachedScopesForMessageId(payload.id),
        };
        if (payload.replyRootId case final int replyRootId) {
          scopes.add(
            ConversationScope.thread(
              chatId: payload.chatId.toString(),
              threadRootId: replyRootId.toString(),
            ),
          );
        } else {
          scopes.add(ConversationScope.chat(chatId: payload.chatId.toString()));
        }

        for (final scope in scopes) {
          if (!store.hasCachedWindowForScope(scope)) {
            continue;
          }
          ref.read(conversationRepositoryProvider(scope)).applyRealtimeEvent(
            event,
          );
        }
        return;
      case ReactionUpdatedWsEvent(:final payload):
        final store = ref.read(messageDomainStoreProvider);
        for (final scope in store.cachedScopesForMessageId(payload.messageId)) {
          if (!store.hasCachedWindowForScope(scope)) {
            continue;
          }
          ref.read(conversationRepositoryProvider(scope)).applyRealtimeEvent(
            event,
          );
        }
        return;
      case ThreadUpdatedWsEvent(:final payload):
        final store = ref.read(messageDomainStoreProvider);
        if (
            !store.hasCachedThreadWindow(
              chatId: payload.chatId.toString(),
              threadRootId: payload.threadRootId,
            )) {
          return;
        }
        ref
            .read(
              conversationRepositoryProvider(
                ConversationScope.thread(
                  chatId: payload.chatId.toString(),
                  threadRootId: payload.threadRootId.toString(),
                ),
              ),
            )
            .applyThreadSummaryUpdate(
              threadRootId: payload.threadRootId,
              replyCount: payload.replyCount,
              lastReplyAt: payload.lastReplyAt,
            );
        return;
      case StickerPackOrderUpdatedWsEvent():
      case PongWsEvent():
        return;
    }
  }

  void applyListProjectionEvent(ApiWsEvent event) {
    switch (event) {
      case MessageCreatedWsEvent():
      case MessageUpdatedWsEvent():
      case MessageDeletedWsEvent():
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
      applyConversationCacheEvent(event);
      switch (event) {
        case MessageCreatedWsEvent():
        case MessageUpdatedWsEvent():
        case MessageDeletedWsEvent():
        case ReactionUpdatedWsEvent():
          ref.read(conversationRealtimeRegistryProvider).dispatch(event);
          break;
        case ThreadUpdatedWsEvent():
        case StickerPackOrderUpdatedWsEvent():
        case PongWsEvent():
          break;
      }
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
