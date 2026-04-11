import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chahua/core/api/models/messages_api_models.dart';
import 'package:chahua/core/api/models/websocket_api_models.dart';
import 'package:chahua/features/chats/conversation/data/conversation_repository.dart';
import 'package:chahua/features/chats/conversation/data/message_api_service.dart';
import 'package:chahua/features/chats/conversation/domain/conversation_scope.dart';
import 'package:chahua/features/chats/models/message_models.dart';

void main() {
  group('ConversationRepository sends', () {
    test('commitSend forwards audio message type and attachment ids', () async {
      final service = _FakeMessageApiService(messages: const []);
      final repository = ConversationRepository(
        scope: const ConversationScope.chat(chatId: '1'),
        service: service,
      );

      await repository.commitSend(
        clientGeneratedId: 'audio-cg-1',
        text: '',
        messageType: 'audio',
        attachmentIds: const ['att-1'],
        replyToId: 7,
      );

      expect(service.lastSendMessageType, 'audio');
      expect(service.lastSendText, '');
      expect(service.lastSendAttachmentIds, const ['att-1']);
      expect(service.lastSendReplyToId, 7);
    });
  });

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
          scope: const ConversationScope.chat(chatId: '1'),
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
          scope: const ConversationScope.chat(chatId: '1'),
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
        scope: const ConversationScope.chat(chatId: '1'),
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
          scope: const ConversationScope.chat(chatId: '1'),
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
        scope: const ConversationScope.chat(chatId: '1'),
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
  String? message = 'Hello',
  String messageType = 'text',
  List<AttachmentItemDto> attachments = const <AttachmentItemDto>[],
  List<ReactionSummaryDto> reactions = const <ReactionSummaryDto>[],
}) {
  return MessageItemDto(
    id: 1,
    message: message,
    messageType: messageType,
    sender: const SenderDto(uid: 7, name: 'Tester'),
    chatId: 1,
    createdAt: DateTime.utc(2026, 1, 1),
    clientGeneratedId: 'cg-1',
    attachments: attachments,
    reactions: reactions,
  );
}

class _FakeMessageApiService extends MessageApiService {
  _FakeMessageApiService({required List<MessageItemDto> messages})
    : _messages = messages,
      super(Dio(), 1);

  final List<MessageItemDto> _messages;
  final List<String> reactionCalls = <String>[];
  bool failPut = false;
  bool failDelete = false;
  String? lastSendText;
  String? lastSendMessageType;
  List<String>? lastSendAttachmentIds;
  int? lastSendReplyToId;

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

  @override
  Future<MessageItemDto> sendConversationMessage(
    ConversationScope scope,
    String text, {
    required String messageType,
    int? replyToId,
    List<String> attachmentIds = const <String>[],
    required String clientGeneratedId,
    String? stickerId,
  }) async {
    lastSendText = text;
    lastSendMessageType = messageType;
    lastSendAttachmentIds = attachmentIds;
    lastSendReplyToId = replyToId;
    return _message(
      message: text,
      messageType: messageType,
      attachments: attachmentIds
          .map(
            (id) => AttachmentItemDto(
              id: id,
              kind: messageType == 'audio' ? 'audio/mp4' : 'application/pdf',
              fileName: id,
            ),
          )
          .toList(growable: false),
    );
  }
}
