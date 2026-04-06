import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wetty_chat_flutter/core/api/models/chats_api_models.dart';
import 'package:wetty_chat_flutter/core/api/models/messages_api_models.dart';
import 'package:wetty_chat_flutter/core/api/models/websocket_api_models.dart';
import 'package:wetty_chat_flutter/core/network/websocket_service.dart';
import 'package:wetty_chat_flutter/features/chats/conversation/application/conversation_timeline_view_model.dart';
import 'package:wetty_chat_flutter/features/chats/conversation/data/message_api_service.dart';
import 'package:wetty_chat_flutter/features/chats/conversation/domain/conversation_scope.dart';
import 'package:wetty_chat_flutter/features/chats/conversation/domain/launch_request.dart';

void main() {
  group('ConversationTimelineViewModel locate plans', () {
    test('latest launch emits prepared live-edge locate', () async {
      final container = _createContainer();
      addTearDown(container.dispose);
      final provider = conversationTimelineViewModelProvider(_args());

      final state = await container.read(provider.future);

      expect(state.locatePlan?.target, ConversationLocateTarget.latest);
      expect(state.locatePlan?.placement, ConversationLocatePlacement.liveEdge);
      expect(
        state.locatePlan?.execution,
        ConversationLocateExecution.preparedViewport,
      );
      expect(state.locatePlan?.viewportSessionId, 1);
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
        final state = container.read(provider).valueOrNull;

        expect(changed, isTrue);
        expect(state, isNotNull);
        expect(state!.windowStableKeys, initial.windowStableKeys);
        expect(state.anchorMessageId, 120);
        expect(state.locatePlan?.target, ConversationLocateTarget.message);
        expect(
          state.locatePlan?.placement,
          ConversationLocatePlacement.topPreferred,
        );
        expect(
          state.locatePlan?.execution,
          ConversationLocateExecution.interactiveViewport,
        );
        expect(
          state.locatePlan?.viewportSessionId,
          initial.locatePlan?.viewportSessionId,
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
        final state = container.read(provider).valueOrNull;

        expect(changed, isTrue);
        expect(state, isNotNull);
        expect(state!.windowStableKeys, isNot(initial.windowStableKeys));
        expect(state.anchorMessageId, 10);
        expect(state.windowStableKeys, contains('server:10'));
        expect(
          state.locatePlan?.execution,
          ConversationLocateExecution.preparedViewport,
        );
        expect(
          state.locatePlan?.viewportSessionId,
          greaterThan(initial.locatePlan?.viewportSessionId ?? 0),
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
        final state = container.read(provider).valueOrNull;

        expect(state, isNotNull);
        expect(state!.windowMode, ConversationWindowMode.liveLatest);
        expect(state.anchorMessageId, isNull);
        expect(
          state.locatePlan?.execution,
          ConversationLocateExecution.interactiveViewport,
        );
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
        final state = container.read(provider).valueOrNull;

        expect(state, isNotNull);
        expect(state!.windowMode, ConversationWindowMode.liveLatest);
        expect(state.anchorMessageId, isNull);
        expect(
          state.locatePlan?.execution,
          ConversationLocateExecution.preparedViewport,
        );
        expect(state.windowStableKeys.first, 'server:51');
        expect(state.windowStableKeys.last, 'server:150');
      },
    );
  });
}

ProviderContainer _createContainer() {
  return ProviderContainer(
    overrides: [
      messageApiServiceProvider.overrideWithValue(
        _FakeMessageApiService(_buildMessages()),
      ),
      wsEventsProvider.overrideWith((ref) => const Stream<ApiWsEvent>.empty()),
    ],
  );
}

ConversationTimelineArgs _args() => (
  scope: const ConversationScope.chat('1'),
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
  _FakeMessageApiService(this._messages) : super(1);

  final List<MessageItemDto> _messages;

  @override
  Future<ListMessagesResponseDto> fetchConversationMessages(
    ConversationScope scope, {
    int? max,
    int? before,
    int? after,
    int? around,
  }) async {
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
