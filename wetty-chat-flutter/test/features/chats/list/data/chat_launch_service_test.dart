import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wetty_chat_flutter/core/api/models/messages_api_models.dart';
import 'package:wetty_chat_flutter/features/chats/conversation/data/message_api_service.dart';
import 'package:wetty_chat_flutter/features/chats/conversation/domain/conversation_scope.dart';
import 'package:wetty_chat_flutter/features/chats/conversation/domain/launch_request.dart';
import 'package:wetty_chat_flutter/features/chats/list/data/chat_launch_service.dart';
import 'package:wetty_chat_flutter/features/chats/models/chat_models.dart';

void main() {
  group('ChatLaunchService', () {
    test('returns latest when chat has no unread count', () async {
      final service = ChatLaunchService(
        messageApiService: _FakeMessageApiService(const <MessageItemDto>[]),
      );

      final request = await service.resolveLaunchRequest(
        ChatListItem(id: '1', unreadCount: 0),
      );

      expect(request, const LaunchRequest.latest());
    });

    test('returns latest when last read id is invalid', () async {
      final service = ChatLaunchService(
        messageApiService: _FakeMessageApiService(const <MessageItemDto>[]),
      );

      final request = await service.resolveLaunchRequest(
        ChatListItem(id: '1', unreadCount: 2, lastReadMessageId: 'abc'),
      );

      expect(request, const LaunchRequest.latest());
    });

    test('returns unread launch when first unread exists', () async {
      final service = ChatLaunchService(
        messageApiService: _FakeMessageApiService(const <MessageItemDto>[
          MessageItemDto(
            id: 51,
            chatId: 1,
            sender: SenderDto(uid: 7, name: 'Tester'),
            message: 'Message 51',
            clientGeneratedId: 'cg-51',
          ),
        ]),
      );

      final request = await service.resolveLaunchRequest(
        ChatListItem(id: '1', unreadCount: 2, lastReadMessageId: '50'),
      );

      expect(request, const LaunchRequest.unread(51));
    });

    test('returns latest when backend has no unread target', () async {
      final service = ChatLaunchService(
        messageApiService: _FakeMessageApiService(const <MessageItemDto>[]),
      );

      final request = await service.resolveLaunchRequest(
        ChatListItem(id: '1', unreadCount: 2, lastReadMessageId: '50'),
      );

      expect(request, const LaunchRequest.latest());
    });

    test(
      'unread probe does not pre-seed conversation cache and block later around loads',
      () async {
        final messageApi = _WindowedFakeMessageApiService(
          messages: _windowedMessages(),
        );
        final launchService = ChatLaunchService(messageApiService: messageApi);

        final request = await launchService.resolveLaunchRequest(
          ChatListItem(id: '1', unreadCount: 2, lastReadMessageId: '50'),
        );

        expect(request, const LaunchRequest.unread(51));
      },
    );
  });
}

class _FakeMessageApiService extends MessageApiService {
  _FakeMessageApiService(this._messages) : super(Dio(), 1);

  final List<MessageItemDto> _messages;

  @override
  Future<ListMessagesResponseDto> fetchConversationMessages(
    ConversationScope scope, {
    int? max,
    int? before,
    int? after,
    int? around,
  }) async {
    expect(before, isNull);
    expect(around, isNull);
    final filtered = after == null
        ? _messages
        : _messages
              .where((message) => message.id > after)
              .toList(growable: false);
    if (max == null || filtered.length <= max) {
      return ListMessagesResponseDto(messages: filtered);
    }
    return ListMessagesResponseDto(messages: filtered.sublist(0, max));
  }
}

class _WindowedFakeMessageApiService extends MessageApiService {
  _WindowedFakeMessageApiService({required List<MessageItemDto> messages})
    : _messages = messages,
      super(Dio(), 1);

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
    if (after != null) {
      final filtered = _messages
          .where((message) => message.id > after)
          .toList(growable: false);
      if (max == null || filtered.length <= max) {
        return ListMessagesResponseDto(messages: filtered);
      }
      return ListMessagesResponseDto(messages: filtered.sublist(0, max));
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
    if (max == null || _messages.length <= max) {
      return ListMessagesResponseDto(messages: _messages);
    }
    return ListMessagesResponseDto(
      messages: _messages.sublist(_messages.length - max),
    );
  }
}

List<MessageItemDto> _windowedMessages() {
  return List<MessageItemDto>.generate(80, (index) {
    final id = index + 1;
    return MessageItemDto(
      id: id,
      message: 'Message $id',
      sender: const SenderDto(uid: 7, name: 'Tester'),
      chatId: 1,
      createdAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: id)),
      clientGeneratedId: 'cg-$id',
    );
  });
}
