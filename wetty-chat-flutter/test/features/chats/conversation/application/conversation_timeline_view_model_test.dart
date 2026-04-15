import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chahua/core/api/models/chats_api_models.dart';
import 'package:chahua/core/api/models/messages_api_models.dart';
import 'package:chahua/core/api/models/websocket_api_models.dart';
import 'package:chahua/features/chats/conversation/application/conversation_timeline_view_model.dart';
import 'package:chahua/features/chats/conversation/application/conversation_realtime_registry.dart';
import 'package:chahua/features/chats/conversation/data/message_api_service.dart';
import 'package:chahua/features/chats/conversation/domain/conversation_scope.dart';
import 'package:chahua/features/chats/conversation/domain/launch_request.dart';
import 'package:chahua/features/chats/conversation/domain/viewport_placement.dart';

void main() {
  group('ConversationTimelineViewModel viewport commands', () {
    test('latest launch emits prepared live-edge command', () async {
      final container = _createContainer();
      addTearDown(container.dispose);
      final provider = conversationTimelineViewModelProvider(_args());

      final state = await container.read(provider.future);

      expect(
        state.viewportCommand?.type,
        ConversationViewportCommandType.showLatest,
      );
      expect(
        state.viewportCommand?.placement,
        ConversationViewportPlacement.liveEdge,
      );
      expect(state.viewportPlacement, ConversationViewportPlacement.liveEdge);
    });

    test(
      'jumpToMessage reuses current window when target is already loaded',
      () async {
        final container = _createContainer();
        addTearDown(container.dispose);
        final provider = conversationTimelineViewModelProvider(_args());

        final initial = await container.read(provider.future);
        final notifier = container.read(provider.notifier);

        final changed = await notifier.jumpToMessage(120);
        final state = container.read(provider).value;

        expect(changed, isTrue);
        expect(state, isNotNull);
        expect(state!.windowStableKeys, initial.windowStableKeys);
        expect(state.anchorMessageId, 120);
        expect(
          state.viewportCommand?.type,
          ConversationViewportCommandType.scrollToLoadedTarget,
        );
        expect(
          state.viewportCommand?.placement,
          ConversationViewportPlacement.topPreferred,
        );
        expect(
          state.viewportPlacement,
          ConversationViewportPlacement.topPreferred,
        );
      },
    );

    test(
      'unread launch at newest message keeps top-preferred placement',
      () async {
        final container = _createContainer();
        addTearDown(container.dispose);
        final provider = conversationTimelineViewModelProvider((
          scope: const ConversationScope.chat(chatId: '1'),
          launchRequest: const LaunchRequest.unread(lastReadMessageId: 149),
        ));

        final state = await container.read(provider.future);

        expect(state.windowMode, ConversationWindowMode.anchoredTarget);
        expect(state.anchorMessageId, 150);
        expect(
          state.viewportCommand?.placement,
          ConversationViewportPlacement.topPreferred,
        );
        expect(
          state.viewportPlacement,
          ConversationViewportPlacement.topPreferred,
        );
      },
    );

    test(
      'jumpToMessage replaces window when target is outside current window',
      () async {
        final container = _createContainer();
        addTearDown(container.dispose);
        final provider = conversationTimelineViewModelProvider(_args());

        final initial = await container.read(provider.future);
        final notifier = container.read(provider.notifier);

        final changed = await notifier.jumpToMessage(10);
        final state = container.read(provider).value;

        expect(changed, isTrue);
        expect(state, isNotNull);
        expect(state!.windowStableKeys, isNot(initial.windowStableKeys));
        expect(state.anchorMessageId, 10);
        expect(state.windowStableKeys, contains('server:10'));
        expect(
          state.viewportCommand?.type,
          ConversationViewportCommandType.bootstrapTarget,
        );
      },
    );

    test(
      'jumpToLatest reuses current window when latest is already loaded',
      () async {
        final container = _createContainer();
        addTearDown(container.dispose);
        final provider = conversationTimelineViewModelProvider(_args());

        await container.read(provider.future);
        final notifier = container.read(provider.notifier);

        await notifier.jumpToMessage(120);
        await notifier.jumpToLatest();
        final state = container.read(provider).value;

        expect(state, isNotNull);
        expect(state!.windowMode, ConversationWindowMode.liveLatest);
        expect(state.anchorMessageId, isNull);
        expect(
          state.viewportCommand?.type,
          ConversationViewportCommandType.settleAtBottomAfterMutation,
        );
        expect(state.viewportPlacement, ConversationViewportPlacement.liveEdge);
      },
    );

    test(
      'jumpToLatest replaces window when returning from far history',
      () async {
        final container = _createContainer();
        addTearDown(container.dispose);
        final provider = conversationTimelineViewModelProvider(_args());

        await container.read(provider.future);
        final notifier = container.read(provider.notifier);

        await notifier.jumpToMessage(10);
        await notifier.jumpToLatest();
        final state = container.read(provider).value;

        expect(state, isNotNull);
        expect(state!.windowMode, ConversationWindowMode.liveLatest);
        expect(state.anchorMessageId, isNull);
        expect(
          state.viewportCommand?.type,
          ConversationViewportCommandType.showLatest,
        );
        expect(state.windowStableKeys.first, 'server:51');
        expect(state.windowStableKeys.last, 'server:150');
        expect(state.viewportPlacement, ConversationViewportPlacement.liveEdge);
      },
    );

    test(
      'loadOlder preserves live-edge placement when leaving latest mode',
      () async {
        final container = _createContainer();
        addTearDown(container.dispose);
        final provider = conversationTimelineViewModelProvider(_args());

        await container.read(provider.future);
        final notifier = container.read(provider.notifier);

        await notifier.loadOlder();
        final state = container.read(provider).value;

        expect(state, isNotNull);
        expect(state!.windowMode, ConversationWindowMode.historyBrowsing);
        expect(state.viewportPlacement, ConversationViewportPlacement.liveEdge);
      },
    );

    test(
      'loadOlder emits preserve-on-prepend when anchor is provided',
      () async {
        final container = _createContainer();
        addTearDown(container.dispose);
        final provider = conversationTimelineViewModelProvider(_args());

        await container.read(provider.future);
        final notifier = container.read(provider.notifier);

        await notifier.loadOlder(
          preserveAnchorStableKey: 'server:120',
          preserveAnchorDy: 24,
          rebaseAnchorMessageId: 120,
        );
        final state = container.read(provider).value;

        expect(state, isNotNull);
        expect(
          state!.viewportCommand?.type,
          ConversationViewportCommandType.preserveOnPrepend,
        );
        expect(state.viewportCommand?.anchorStableKey, 'server:120');
        expect(state.viewportCommand?.anchorDy, 24);
      },
    );

    test(
      'loaded jump while already browsing history keeps the existing pivot',
      () async {
        final container = _createContainer();
        addTearDown(container.dispose);
        final provider = conversationTimelineViewModelProvider(_args());

        await container.read(provider.future);
        final notifier = container.read(provider.notifier);

        await notifier.jumpToMessage(120);
        final firstJumpTransaction = container
            .read(provider)
            .value!
            .viewportCommand!
            .transactionId;
        notifier.consumeViewportCommand(firstJumpTransaction);

        await notifier.jumpToMessage(130);
        final state = container.read(provider).value;

        expect(state, isNotNull);
        expect(state!.windowMode, ConversationWindowMode.historyBrowsing);
        expect(state.anchorMessageId, 120);
        expect(
          state.viewportCommand?.type,
          ConversationViewportCommandType.scrollToLoadedTarget,
        );
      },
    );

    test(
      'viewport resize emits bottom-settle command only while at live latest',
      () async {
        final container = _createContainer();
        addTearDown(container.dispose);
        final provider = conversationTimelineViewModelProvider(_args());

        await container.read(provider.future);
        final notifier = container.read(provider.notifier);

        notifier.onViewportResized();
        final liveLatestState = container.read(provider).value;

        expect(liveLatestState, isNotNull);
        expect(
          liveLatestState!.viewportCommand?.type,
          ConversationViewportCommandType.settleAtBottomAfterViewportResize,
        );

        await notifier.jumpToMessage(120);
        notifier.onViewportResized();
        final historyState = container.read(provider).value;

        expect(historyState, isNotNull);
        expect(
          historyState!.viewportCommand?.type,
          ConversationViewportCommandType.scrollToLoadedTarget,
        );
      },
    );

    test(
      'realtime message while out of live edge appends into latest-backed window without settling bottom',
      () async {
        final container = _createContainer();
        addTearDown(container.dispose);
        final provider = conversationTimelineViewModelProvider(_args());

        await container.read(provider.future);
        final notifier = container.read(provider.notifier);
        final initialTransactionId = container
            .read(provider)
            .value!
            .viewportCommand!
            .transactionId;
        notifier.consumeViewportCommand(initialTransactionId);
        notifier.onViewportLiveEdgeChanged(false);

        container
            .read(conversationRealtimeRegistryProvider)
            .dispatch(
              MessageCreatedWsEvent(
                payload: MessageItemDto(
                  id: 151,
                  message: 'Message 151',
                  sender: const SenderDto(uid: 7, name: 'Tester'),
                  chatId: 1,
                  createdAt: DateTime.utc(
                    2026,
                    1,
                    1,
                  ).add(const Duration(minutes: 151)),
                  clientGeneratedId: 'cg-151',
                ),
              ),
            );

        final state = container.read(provider).value;

        expect(state, isNotNull);
        expect(state!.pendingLiveCount, 1);
        expect(state.windowStableKeys.last, 'server:151');
        expect(state.viewportCommand, isNull);
      },
    );

    test(
      'realtime message deep in history does not append into the current historical window',
      () async {
        final container = _createContainer();
        addTearDown(container.dispose);
        final provider = conversationTimelineViewModelProvider(_args());

        await container.read(provider.future);
        final notifier = container.read(provider.notifier);

        await notifier.jumpToMessage(10);
        final transactionId = container
            .read(provider)
            .value!
            .viewportCommand!
            .transactionId;
        notifier.consumeViewportCommand(transactionId);
        notifier.onViewportLiveEdgeChanged(false);

        container
            .read(conversationRealtimeRegistryProvider)
            .dispatch(
              MessageCreatedWsEvent(
                payload: MessageItemDto(
                  id: 151,
                  message: 'Message 151',
                  sender: const SenderDto(uid: 7, name: 'Tester'),
                  chatId: 1,
                  createdAt: DateTime.utc(
                    2026,
                    1,
                    1,
                  ).add(const Duration(minutes: 151)),
                  clientGeneratedId: 'cg-151',
                ),
              ),
            );

        final state = container.read(provider).value;

        expect(state, isNotNull);
        expect(state!.pendingLiveCount, 1);
        expect(state.windowStableKeys, isNot(contains('server:151')));
      },
    );

    test(
      'realtime delete removes an unseen created message from pending count',
      () async {
        final container = _createContainer();
        addTearDown(container.dispose);
        final provider = conversationTimelineViewModelProvider(_args());

        await container.read(provider.future);
        final notifier = container.read(provider.notifier);
        final initialTransactionId = container
            .read(provider)
            .value!
            .viewportCommand!
            .transactionId;
        notifier.consumeViewportCommand(initialTransactionId);
        notifier.onViewportLiveEdgeChanged(false);

        final registry = container.read(conversationRealtimeRegistryProvider);
        registry.dispatch(
          MessageCreatedWsEvent(
            payload: MessageItemDto(
              id: 151,
              message: 'Message 151',
              sender: const SenderDto(uid: 7, name: 'Tester'),
              chatId: 1,
              createdAt: DateTime.utc(
                2026,
                1,
                1,
              ).add(const Duration(minutes: 151)),
              clientGeneratedId: 'cg-151',
            ),
          ),
        );
        registry.dispatch(
          MessageDeletedWsEvent(
            payload: MessageItemDto(
              id: 151,
              message: 'Message 151',
              sender: const SenderDto(uid: 7, name: 'Tester'),
              chatId: 1,
              createdAt: DateTime.utc(
                2026,
                1,
                1,
              ).add(const Duration(minutes: 151)),
              clientGeneratedId: 'cg-151',
              isDeleted: true,
            ),
          ),
        );

        final state = container.read(provider).value;

        expect(state, isNotNull);
        expect(state!.pendingLiveCount, 0);
      },
    );

    test('re-entering live edge clears pending live count', () async {
      final container = _createContainer();
      addTearDown(container.dispose);
      final provider = conversationTimelineViewModelProvider(_args());

      await container.read(provider.future);
      final notifier = container.read(provider.notifier);
      final initialTransactionId = container
          .read(provider)
          .value!
          .viewportCommand!
          .transactionId;
      notifier.consumeViewportCommand(initialTransactionId);
      notifier.onViewportLiveEdgeChanged(false);

      container
          .read(conversationRealtimeRegistryProvider)
          .dispatch(
            MessageCreatedWsEvent(
              payload: MessageItemDto(
                id: 151,
                message: 'Message 151',
                sender: const SenderDto(uid: 7, name: 'Tester'),
                chatId: 1,
                createdAt: DateTime.utc(
                  2026,
                  1,
                  1,
                ).add(const Duration(minutes: 151)),
                clientGeneratedId: 'cg-151',
              ),
            ),
          );

      notifier.onViewportLiveEdgeChanged(true);
      final state = container.read(provider).value;

      expect(state, isNotNull);
      expect(state!.pendingLiveCount, 0);
    });

    test('consumeViewportCommand clears command from state', () async {
      final container = _createContainer();
      addTearDown(container.dispose);
      final provider = conversationTimelineViewModelProvider(_args());

      await container.read(provider.future);
      final notifier = container.read(provider.notifier);
      final transactionId = container
          .read(provider)
          .value!
          .viewportCommand!
          .transactionId;

      expect(container.read(provider).value?.viewportCommand, isNotNull);
      notifier.consumeViewportCommand(transactionId);
      expect(container.read(provider).value?.viewportCommand, isNull);
    });

    test('warm latest launch restores cache then refreshes on open', () async {
      final service = _FakeMessageApiService(_buildMessages());
      final container = _createContainer(service: service);
      addTearDown(container.dispose);
      final provider = conversationTimelineViewModelProvider(_args());
      final sub = container.listen(provider, (_, _) {}, fireImmediately: true);
      addTearDown(sub.close);

      await container.read(provider.future);
      expect(service.latestFetchCount, 1);

      service.appendMessage(151);
      container.invalidate(provider);

      final restored = await container.read(provider.future);
      expect(restored.windowStableKeys.last, 'server:150');
      expect(service.latestFetchCount, 1);

      await container.read(provider.notifier).refreshEntryOnOpenIfNeeded();
      final refreshed = container.read(provider).value;

      expect(refreshed, isNotNull);
      expect(service.latestFetchCount, 2);
      expect(refreshed!.windowStableKeys.last, 'server:151');
      expect(refreshed.windowMode, ConversationWindowMode.liveLatest);
    });

    test('resume refresh updates a live latest window', () async {
      final service = _FakeMessageApiService(_buildMessages());
      final container = _createContainer(service: service);
      addTearDown(container.dispose);
      final provider = conversationTimelineViewModelProvider(_args());

      await container.read(provider.future);
      expect(service.latestFetchCount, 1);

      service.appendMessage(151);

      await container.read(provider.notifier).refreshOnResume();
      final refreshed = container.read(provider).value;

      expect(refreshed, isNotNull);
      expect(service.latestFetchCount, 2);
      expect(refreshed!.windowMode, ConversationWindowMode.liveLatest);
      expect(refreshed.windowStableKeys.last, 'server:151');
    });

    test(
      'warm anchored launch restores cache then refreshes on open',
      () async {
        final service = _FakeMessageApiService(_buildMessages());
        final container = _createContainer(service: service);
        addTearDown(container.dispose);
        final latestProvider = conversationTimelineViewModelProvider(_args());
        final anchoredProvider = conversationTimelineViewModelProvider((
          scope: const ConversationScope.chat(chatId: '1'),
          launchRequest: const LaunchRequest.message(messageId: 149),
        ));

        await container.read(latestProvider.future);
        expect(service.latestFetchCount, 1);

        service.appendMessage(151);

        final restored = await container.read(anchoredProvider.future);
        expect(restored.anchorMessageId, 149);
        expect(restored.windowStableKeys.last, 'server:150');
        expect(service.aroundFetchCount, 0);

        await container
            .read(anchoredProvider.notifier)
            .refreshEntryOnOpenIfNeeded();
        final refreshed = container.read(anchoredProvider).value;

        expect(refreshed, isNotNull);
        expect(service.aroundFetchCount, 1);
        expect(refreshed!.anchorMessageId, 149);
        expect(refreshed.windowMode, ConversationWindowMode.anchoredTarget);
        expect(refreshed.windowStableKeys.last, 'server:151');
        expect(refreshed.canLoadNewer, isFalse);
      },
    );

    test('resume refresh updates an anchored window', () async {
      final service = _FakeMessageApiService(_buildMessages());
      final container = _createContainer(service: service);
      addTearDown(container.dispose);
      final latestProvider = conversationTimelineViewModelProvider(_args());
      final anchoredProvider = conversationTimelineViewModelProvider((
        scope: const ConversationScope.chat(chatId: '1'),
        launchRequest: const LaunchRequest.message(messageId: 149),
      ));

      await container.read(latestProvider.future);
      final anchored = await container.read(anchoredProvider.future);

      expect(anchored.anchorMessageId, 149);
      expect(service.aroundFetchCount, 0);

      service.appendMessage(151);

      await container.read(anchoredProvider.notifier).refreshOnResume();
      final refreshed = container.read(anchoredProvider).value;

      expect(refreshed, isNotNull);
      expect(service.aroundFetchCount, 1);
      expect(refreshed!.windowMode, ConversationWindowMode.anchoredTarget);
      expect(refreshed.anchorMessageId, 149);
      expect(refreshed.windowStableKeys.last, 'server:151');
    });

    test('resume refresh does not disturb history browsing state', () async {
      final service = _FakeMessageApiService(_buildMessages());
      final container = _createContainer(service: service);
      addTearDown(container.dispose);
      final provider = conversationTimelineViewModelProvider(_args());

      await container.read(provider.future);
      final notifier = container.read(provider.notifier);

      await notifier.jumpToMessage(120);
      service.appendMessage(151);

      await notifier.refreshOnResume();
      final refreshed = container.read(provider).value;

      expect(refreshed, isNotNull);
      expect(service.latestFetchCount, 1);
      expect(service.aroundFetchCount, 0);
      expect(refreshed!.windowMode, ConversationWindowMode.historyBrowsing);
      expect(refreshed.anchorMessageId, 120);
      expect(refreshed.windowStableKeys, contains('server:120'));
      expect(refreshed.windowStableKeys, isNot(contains('server:151')));
    });

    test(
      'entry refresh does not clobber mode changes before it completes',
      () async {
        final service = _FakeMessageApiService(_buildMessages());
        final container = _createContainer(service: service);
        addTearDown(container.dispose);
        final provider = conversationTimelineViewModelProvider(_args());
        final sub = container.listen(
          provider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(sub.close);

        await container.read(provider.future);
        service.appendMessage(151);
        container.invalidate(provider);
        await container.read(provider.future);

        final notifier = container.read(provider.notifier);
        await notifier.jumpToMessage(120);
        await notifier.refreshEntryOnOpenIfNeeded();
        final state = container.read(provider).value;

        expect(state, isNotNull);
        expect(state!.windowMode, ConversationWindowMode.historyBrowsing);
        expect(state.anchorMessageId, 120);
        expect(service.latestFetchCount, 1);
      },
    );
  });
}

ProviderContainer _createContainer({_FakeMessageApiService? service}) {
  return ProviderContainer(
    overrides: [
      messageApiServiceProvider.overrideWithValue(
        service ?? _FakeMessageApiService(_buildMessages()),
      ),
    ],
  );
}

ConversationTimelineArgs _args() => (
  scope: const ConversationScope.chat(chatId: '1'),
  launchRequest: const LaunchRequest.latest(),
);

List<MessageItemDto> _buildMessages() {
  const sender = SenderDto(uid: 7, name: 'Tester');
  return List<MessageItemDto>.generate(150, (index) {
    final id = index + 1;
    return MessageItemDto(
      id: id,
      message: 'Message $id',
      sender: sender,
      chatId: 1,
      createdAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: id)),
      clientGeneratedId: 'cg-$id',
    );
  });
}

class _FakeMessageApiService extends MessageApiService {
  _FakeMessageApiService(this._messages) : super(Dio(), 1);

  final List<MessageItemDto> _messages;
  int latestFetchCount = 0;
  int aroundFetchCount = 0;

  void appendMessage(int id) {
    _messages.add(
      MessageItemDto(
        id: id,
        message: 'Message $id',
        sender: const SenderDto(uid: 7, name: 'Tester'),
        chatId: 1,
        createdAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: id)),
        clientGeneratedId: 'cg-$id',
      ),
    );
  }

  @override
  Future<ListMessagesResponseDto> fetchConversationMessages(
    ConversationScope scope, {
    int? max,
    int? before,
    int? after,
    int? around,
  }) async {
    if (around != null) {
      aroundFetchCount += 1;
    } else if (before == null && after == null) {
      latestFetchCount += 1;
    }
    if (around != null) {
      final index = _messages.indexWhere((message) => message.id == around);
      if (index < 0) {
        return const ListMessagesResponseDto();
      }
      final limit = max ?? _messages.length;
      final beforeCount = (limit - 1) ~/ 2;
      final afterCount = limit - beforeCount - 1;
      final end = (index + afterCount + 1).clamp(0, _messages.length);
      final adjustedStart = (end - limit).clamp(0, _messages.length);
      return ListMessagesResponseDto(
        messages: _messages.sublist(adjustedStart, end),
      );
    }
    if (before != null) {
      final filtered = _messages
          .where((message) => message.id < before)
          .toList(growable: false);
      if (max == null || filtered.length <= max) {
        return ListMessagesResponseDto(messages: filtered);
      }
      return ListMessagesResponseDto(
        messages: filtered.sublist(filtered.length - max),
      );
    }
    if (after != null) {
      final filtered = _messages
          .where((message) => message.id > after)
          .toList(growable: false);
      if (max == null || filtered.length <= max) {
        return ListMessagesResponseDto(messages: filtered);
      }
      return ListMessagesResponseDto(messages: filtered.sublist(0, max));
    }
    if (max == null || _messages.length <= max) {
      return ListMessagesResponseDto(messages: _messages);
    }
    return ListMessagesResponseDto(
      messages: _messages.sublist(_messages.length - max),
    );
  }

  @override
  Future<MarkChatReadStateResponseDto> markMessagesAsRead(
    String chatId,
    int messageId,
  ) async {
    return const MarkChatReadStateResponseDto();
  }
}
