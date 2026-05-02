import 'package:chahua/core/api/models/messages_api_models.dart';
import 'package:chahua/features/conversation/compose/data/message_api_service_v2.dart';
import 'package:chahua/features/conversation/shared/application/conversation_canonical_message_store.dart';
import 'package:chahua/features/conversation/shared/data/conversation_timeline_v2_repository.dart';
import 'package:chahua/features/conversation/shared/domain/conversation_identity.dart';
import 'package:chahua/features/conversation/shared/domain/conversation_timeline_v2_active_segment.dart';
import 'package:chahua/features/conversation/shared/domain/conversation_timeline_v2_canonical_scope.dart';
import 'package:chahua/features/shared/model/message/message.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConversationTimelineV2Repository latest edge cursors', () {
    test(
      'around response without a newer cursor marks latest reached',
      () async {
        final api = _FakeMessageApiService([
          _response(messages: [_message(3), _message(4)], prevCursor: null),
        ]);
        final container = _container(api);
        addTearDown(container.dispose);

        await container
            .read(conversationTimelineV2RepositoryProvider(_identity))
            .refreshAroundServerMessageId(3, limit: 10);

        final activeSegment = _activeSegment(container, 3);
        expect(activeSegment.isLatestSlice, true);
        expect(activeSegment.canLoadAfter, false);
      },
    );

    test(
      'after response without a newer cursor marks latest reached',
      () async {
        final api = _FakeMessageApiService([
          _response(messages: [_message(3), _message(4)], prevCursor: null),
        ]);
        final container = _container(api);
        addTearDown(container.dispose);
        _store(container).putScope(_identity, _scope([_segment(1, 2)]));

        await container
            .read(conversationTimelineV2RepositoryProvider(_identity))
            .loadNewerAfterAnchor(2, limit: 10);

        final activeSegment = _activeSegment(container, 2);
        expect(
          activeSegment.orderedMessages.map(
            (message) => message.serverMessageId,
          ),
          [1, 2, 3, 4],
        );
        expect(activeSegment.isLatestSlice, true);
        expect(activeSegment.canLoadAfter, false);
      },
    );

    test('empty after response marks latest reached', () async {
      final api = _FakeMessageApiService([
        _response(messages: const [], prevCursor: null),
      ]);
      final container = _container(api);
      addTearDown(container.dispose);
      _store(container).putScope(_identity, _scope([_segment(1, 2)]));

      await container
          .read(conversationTimelineV2RepositoryProvider(_identity))
          .loadNewerAfterAnchor(2, limit: 10);

      final activeSegment = _activeSegment(container, 2);
      expect(activeSegment.isLatestSlice, true);
      expect(activeSegment.canLoadAfter, false);
    });

    test('newer cursor keeps newer loading enabled', () async {
      final api = _FakeMessageApiService([
        _response(messages: [_message(3), _message(4)], prevCursor: '4'),
      ]);
      final container = _container(api);
      addTearDown(container.dispose);
      _store(container).putScope(_identity, _scope([_segment(1, 2)]));

      await container
          .read(conversationTimelineV2RepositoryProvider(_identity))
          .loadNewerAfterAnchor(2, limit: 10);

      final activeSegment = _activeSegment(container, 2);
      expect(activeSegment.isLatestSlice, false);
      expect(activeSegment.canLoadAfter, true);
    });
  });
}

const _identity = (chatId: 42, threadRootId: null);

ProviderContainer _container(_FakeMessageApiService api) {
  return ProviderContainer(
    overrides: [messageApiServiceV2Provider.overrideWithValue(api)],
  );
}

ConversationTimelineMessageStore _store(ProviderContainer container) {
  return container.read(conversationTimelineMessageStoreProvider.notifier);
}

ConversationTimelineActiveSegment _activeSegment(
  ProviderContainer container,
  int targetServerMessageId,
) {
  return container.read(
    conversationTimelineActiveSegmentProvider((
      identity: _identity,
      mode: ConversationTimelineActiveSegmentMode.around(targetServerMessageId),
    )),
  )!;
}

ConversationTimelineCanonicalScope _scope(
  List<ConversationTimelineCanonicalSegment> segments,
) {
  return ConversationTimelineCanonicalScope(segments: segments);
}

ConversationTimelineCanonicalSegment _segment(int start, int end) {
  return ConversationTimelineCanonicalSegment(
    orderedMessages: [
      for (var id = start; id <= end; id++)
        ConversationMessageV2.fromMessageItemDto(_message(id)),
    ],
  );
}

MessageItemDto _message(int id) {
  return MessageItemDto(
    id: id,
    message: 'message-$id',
    sender: const UserDto(uid: 7, name: 'Sender'),
    chatId: _identity.chatId,
    clientGeneratedId: 'client-$id',
  );
}

ListMessagesResponseDto _response({
  required List<MessageItemDto> messages,
  String? nextCursor,
  String? prevCursor,
}) {
  return ListMessagesResponseDto(
    messages: messages,
    nextCursor: nextCursor,
    prevCursor: prevCursor,
  );
}

class _FakeMessageApiService extends MessageApiServiceV2 {
  _FakeMessageApiService(this.responses) : super(Dio(), 7);

  final List<ListMessagesResponseDto> responses;
  final requests = <({int? before, int? after, int? around, int? max})>[];

  @override
  Future<ListMessagesResponseDto> fetchConversationMessages(
    ConversationIdentity identity, {
    int? max,
    int? before,
    int? after,
    int? around,
  }) async {
    requests.add((before: before, after: after, around: around, max: max));
    return responses.removeAt(0);
  }
}
