import 'package:chahua/features/chats/conversation_v2/application/conversation_timeline_v2_message_store.dart';
import 'package:chahua/features/chats/conversation_v2/data/fake_conversation_timeline_v2_repository.dart';
import 'package:chahua/features/chats/conversation_v2/domain/conversation_message_v2.dart';
import 'package:chahua/features/chats/conversation_v2/domain/conversation_timeline_v2_canonical_scope.dart';
import 'package:chahua/features/chats/models/message_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _identity = (chatId: 'chat-1', threadRootId: null);
const _sender = Sender(uid: 1, name: 'Alice');

void main() {
  group('FakeConversationTimelineV2Repository.ensureLatestSegmentLoaded', () {
    test('seeds the latest segment into an empty scope', () async {
      // Tests the base latest-load flow: the repository populates the store and
      // the latest active-segment provider exposes that seeded tail to the VM.
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final repository = container.read(
        fakeConversationTimelineV2RepositoryProvider(_identity),
      );

      await repository.ensureLatestSegmentLoaded(limit: 3);

      final scope = container.read(
        conversationTimelineV2MessageStoreProvider,
      )[_identity]!;
      final latestSegment = container.read(
        conversationTimelineV2LatestActiveSegmentProvider(_identity),
      )!;

      expect(scope.hasLatestSegment, true);
      expect(_segmentIds(scope.segments), [
        [1, 2, 3],
      ]);
      expect(
        latestSegment.orderedMessages.map((message) => message.serverMessageId),
        [1, 2, 3],
      );
      expect(latestSegment.canLoadBefore, true);
      expect(latestSegment.canLoadAfter, false);
    });

    test(
      'adds a latest segment when only historical segments are cached',
      () async {
        // Tests the gap this change fixes: a scope may already have cached
        // history, but still lack a latest tail. The repository must seed the
        // latest tail anyway so the VM has something current to render.
        final container = ProviderContainer();
        addTearDown(container.dispose);
        container
            .read(conversationTimelineV2MessageStoreProvider.notifier)
            .putScope(_identity, (
              segments: [_segment(10, 12)],
              hasLatestSegment: false,
            ));
        final repository = container.read(
          fakeConversationTimelineV2RepositoryProvider(_identity),
        );

        await repository.ensureLatestSegmentLoaded(limit: 3);

        final scope = container.read(
          conversationTimelineV2MessageStoreProvider,
        )[_identity]!;
        final latestSegment = container.read(
          conversationTimelineV2LatestActiveSegmentProvider(_identity),
        )!;

        expect(scope.hasLatestSegment, true);
        expect(_segmentIds(scope.segments), [
          [1, 2, 3],
        ]);
        expect(
          latestSegment.orderedMessages.map(
            (message) => message.serverMessageId,
          ),
          [1, 2, 3],
        );
      },
    );

    test('does not overwrite an existing latest segment', () async {
      // Tests the steady-state path: once the store already has a latest tail,
      // asking the repository to ensure it exists should leave the cached tail
      // untouched.
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(conversationTimelineV2MessageStoreProvider.notifier)
          .putScope(_identity, (
            segments: [_segment(40, 42)],
            hasLatestSegment: true,
          ));
      final repository = container.read(
        fakeConversationTimelineV2RepositoryProvider(_identity),
      );

      await repository.ensureLatestSegmentLoaded(limit: 3);

      final scope = container.read(
        conversationTimelineV2MessageStoreProvider,
      )[_identity]!;
      final latestSegment = container.read(
        conversationTimelineV2LatestActiveSegmentProvider(_identity),
      )!;

      expect(scope.hasLatestSegment, true);
      expect(_segmentIds(scope.segments), [
        [40, 41, 42],
      ]);
      expect(
        latestSegment.orderedMessages.map((message) => message.serverMessageId),
        [40, 41, 42],
      );
    });
  });
}

ConversationTimelineV2CanonicalSegment _segment(int start, int end) {
  return ConversationTimelineV2CanonicalSegment(
    orderedMessages: [for (var id = start; id <= end; id++) _message(id)],
  );
}

List<List<int>> _segmentIds(
  List<ConversationTimelineV2CanonicalSegment> segments,
) {
  return [
    for (final segment in segments)
      [for (final message in segment.orderedMessages) message.serverMessageId!],
  ];
}

ConversationMessageV2 _message(int serverMessageId) {
  return ConversationMessageV2(
    serverMessageId: serverMessageId,
    clientGeneratedId: 'client-$serverMessageId',
    sender: _sender,
    content: TextMessageContent(text: 'message-$serverMessageId'),
  );
}
