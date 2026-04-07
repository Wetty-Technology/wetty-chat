import 'package:flutter_test/flutter_test.dart';

import 'package:wetty_chat_flutter/core/api/models/messages_api_models.dart';
import 'package:wetty_chat_flutter/core/api/models/websocket_api_models.dart';
import 'package:wetty_chat_flutter/features/chats/conversation/data/conversation_repository.dart';
import 'package:wetty_chat_flutter/features/chats/conversation/data/message_api_service.dart';
import 'package:wetty_chat_flutter/features/chats/conversation/domain/conversation_scope.dart';
import 'package:wetty_chat_flutter/features/chats/models/message_models.dart';

void main() {
  group('ConversationRepository reactions', () {
    test(
      'toggleReaction removes an existing self reaction optimistically',
      () async {
        final service = _FakeMessageApiService(
          messages: [
            _message(
              reactions: [
                const ReactionSummaryDto(
                  emoji: '👍',
                  count: 1,
                  reactedByMe: true,
                ),
              ],
            ),
          ],
        );
        final repository = ConversationRepository(
          scope: const ConversationScope.chat('1'),
          service: service,
        );

        await repository.loadLatestWindow();
        await repository.toggleReaction(messageId: 1, emoji: '👍');

        expect(service.reactionCalls, ['delete:1:👍']);
        expect(repository.messageForServerId(1)?.reactions, isEmpty);
      },
    );

    test(
      'toggleReaction adds a reaction optimistically when missing',
      () async {
        final service = _FakeMessageApiService(messages: [_message()]);
        final repository = ConversationRepository(
          scope: const ConversationScope.chat('1'),
          service: service,
        );

        await repository.loadLatestWindow();
        await repository.toggleReaction(messageId: 1, emoji: '🔥');

        expect(service.reactionCalls, ['put:1:🔥']);
        expect(repository.messageForServerId(1)?.reactions, [
          const ReactionSummary(emoji: '🔥', count: 1, reactedByMe: true),
        ]);
      },
    );

    test('toggleReaction rolls back when the request fails', () async {
      final service = _FakeMessageApiService(messages: [_message()]);
      service.failPut = true;
      final repository = ConversationRepository(
        scope: const ConversationScope.chat('1'),
        service: service,
      );

      await repository.loadLatestWindow();

      await expectLater(
        repository.toggleReaction(messageId: 1, emoji: '🔥'),
        throwsException,
      );

      expect(service.reactionCalls, ['put:1:🔥']);
      expect(repository.messageForServerId(1)?.reactions, isEmpty);
    });

    test(
      'reactionUpdated websocket events override the cached reaction summary',
      () async {
        final service = _FakeMessageApiService(
          messages: [
            _message(
              reactions: [
                const ReactionSummaryDto(
                  emoji: '👍',
                  count: 1,
                  reactedByMe: true,
                ),
              ],
            ),
          ],
        );
        final repository = ConversationRepository(
          scope: const ConversationScope.chat('1'),
          service: service,
        );

        await repository.loadLatestWindow();
        final handled = repository.applyRealtimeEvent(
          ReactionUpdatedWsEvent(
            payload: ReactionUpdatePayloadDto(
              messageId: 1,
              chatId: 1,
              reactions: [
                ReactionSummaryDto(
                  emoji: '👍',
                  count: 2,
                  reactors: [
                    const ReactionReactorDto(uid: 7, name: 'Tester'),
                    const ReactionReactorDto(uid: 8, name: 'Peer'),
                  ],
                ),
              ],
            ),
          ),
        );

        expect(handled, isTrue);
        expect(repository.messageForServerId(1)?.reactions, [
          const ReactionSummary(
            emoji: '👍',
            count: 2,
            reactedByMe: true,
            reactors: [
              ReactionReactor(uid: 7, name: 'Tester'),
              ReactionReactor(uid: 8, name: 'Peer'),
            ],
          ),
        ]);
      },
    );

    test('toggleReaction rejects stickers', () async {
      final service = _FakeMessageApiService(
        messages: [_message(messageType: 'sticker')],
      );
      final repository = ConversationRepository(
        scope: const ConversationScope.chat('1'),
        service: service,
      );

      await repository.loadLatestWindow();

      await expectLater(
        repository.toggleReaction(messageId: 1, emoji: '🔥'),
        throwsUnsupportedError,
      );
      expect(service.reactionCalls, isEmpty);
    });
  });
}

MessageItemDto _message({
  String messageType = 'text',
  List<ReactionSummaryDto> reactions = const <ReactionSummaryDto>[],
}) {
  return MessageItemDto(
    id: 1,
    message: 'Hello',
    messageType: messageType,
    sender: const SenderDto(uid: 7, name: 'Tester'),
    chatId: 1,
    createdAt: DateTime.utc(2026, 1, 1),
    clientGeneratedId: 'cg-1',
    reactions: reactions,
  );
}

class _FakeMessageApiService extends MessageApiService {
  _FakeMessageApiService({required List<MessageItemDto> messages})
    : _messages = messages,
      super(1);

  final List<MessageItemDto> _messages;
  final List<String> reactionCalls = <String>[];
  bool failPut = false;
  bool failDelete = false;

  @override
  Future<ListMessagesResponseDto> fetchConversationMessages(
    ConversationScope scope, {
    int? max,
    int? before,
    int? after,
    int? around,
  }) async {
    return ListMessagesResponseDto(messages: _messages);
  }

  @override
  Future<void> putReaction(
    ConversationScope scope,
    int messageId,
    String emoji,
  ) async {
    reactionCalls.add('put:$messageId:$emoji');
    if (failPut) {
      throw Exception('put failed');
    }
  }

  @override
  Future<void> deleteReaction(
    ConversationScope scope,
    int messageId,
    String emoji,
  ) async {
    reactionCalls.add('delete:$messageId:$emoji');
    if (failDelete) {
      throw Exception('delete failed');
    }
  }
}
