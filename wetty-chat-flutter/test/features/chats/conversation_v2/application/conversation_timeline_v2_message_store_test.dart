import 'package:chahua/features/chats/conversation_v2/application/conversation_timeline_v2_message_store.dart';
import 'package:chahua/features/chats/conversation_v2/domain/conversation_message_v2.dart';
import 'package:chahua/features/chats/conversation_v2/domain/conversation_timeline_v2_canonical_scope.dart';
import 'package:chahua/features/chats/models/message_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _identity = (chatId: 'chat-1', threadRootId: null);
const _sender = Sender(uid: 1, name: 'Alice');

void main() {
  group('ConversationTimelineV2CanonicalSegment', () {
    test('rejects empty segments', () {
      // Tests the invariant that canonical cache segments must contain at least
      // one message so the store never has to reason about empty ranges.
      expect(
        () => ConversationTimelineV2CanonicalSegment(orderedMessages: const []),
        throwsA(isA<AssertionError>()),
      );
    });

    test('rejects messages without server ids', () {
      // Tests the invariant that canonical cached segments are always ordered by
      // server id, so every message in the segment must have one.
      expect(
        () => ConversationTimelineV2CanonicalSegment(
          orderedMessages: [_message(null)],
        ),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  group('ConversationTimelineV2MessageStore', () {
    group('insertBeforeAnchor', () {
      test('inserts the incoming segment into an empty scope', () {
        // Tests the base case: when nothing is cached yet, a before-anchor
        // fetch simply becomes the first cached segment.
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final store = container.read(
          conversationTimelineV2MessageStoreProvider.notifier,
        );

        store.insertBeforeAnchor(_identity, 5, _segment(3, 4));

        final segments = container
            .read(conversationTimelineV2MessageStoreProvider)[_identity]!
            .segments;
        expect(_segmentIds(segments), [
          [3, 4],
        ]);
      });

      test('splits a segment that already contains the anchor', () {
        // Tests the main before-anchor refresh case: keep the stale older
        // prefix, replace the refreshed before-anchor interval, and preserve
        // the anchor itself as a trailing suffix segment.
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final store = container.read(
          conversationTimelineV2MessageStoreProvider.notifier,
        );

        store.putScope(_identity, _scope([_segment(1, 5)]));

        store.insertBeforeAnchor(_identity, 5, _segment(3, 4));

        final segments = container
            .read(conversationTimelineV2MessageStoreProvider)[_identity]!
            .segments;
        expect(_segmentIds(segments), [
          [1, 2],
          [3, 4, 5],
        ]);
      });

      test('split a segment', () {
        // Tests that cached history entirely before the incoming interval stays
        // untouched and ordered ahead of the fresh before-anchor slice.
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final store = container.read(
          conversationTimelineV2MessageStoreProvider.notifier,
        );

        store.putScope(_identity, _scope([_segment(1, 2), _segment(5, 10)]));

        store.insertBeforeAnchor(_identity, 8, _segment(6, 7));

        final segments = container
            .read(conversationTimelineV2MessageStoreProvider)[_identity]!
            .segments;
        expect(_segmentIds(segments), [
          [1, 2],
          [5],
          [6, 7, 8, 9, 10],
        ]);
      });

      test('split a segment / remove elemtns if needed', () {
        // Tests that cached history entirely before the incoming interval stays
        // untouched and ordered ahead of the fresh before-anchor slice.
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final store = container.read(
          conversationTimelineV2MessageStoreProvider.notifier,
        );

        store.putScope(_identity, _scope([_segment(1, 2), _segment(5, 6)]));

        store.insertBeforeAnchor(_identity, 6, _segment(3, 4));

        final segments = container
            .read(conversationTimelineV2MessageStoreProvider)[_identity]!
            .segments;
        expect(_segmentIds(segments), [
          [1, 2],
          [3, 4, 6],
        ]);
      });

      test('keeps an older discontiguous segment before the refreshed slice', () {
        // Tests that cached history entirely before the incoming interval stays
        // untouched and ordered ahead of the fresh before-anchor slice.
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final store = container.read(
          conversationTimelineV2MessageStoreProvider.notifier,
        );

        store.putScope(_identity, _scope([_segment(1, 2), _segment(5, 6)]));

        store.insertBeforeAnchor(_identity, 5, _segment(3, 4));

        final segments = container
            .read(conversationTimelineV2MessageStoreProvider)[_identity]!
            .segments;
        expect(_segmentIds(segments), [
          [1, 2],
          [3, 4, 5, 6],
        ]);
      });

      test(
        'inserts before later segments that start at or after the anchor',
        () {
          // Tests that segments entirely on the anchor/newer side are preserved
          // after the new before-anchor slice without being modified.
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final store = container.read(
            conversationTimelineV2MessageStoreProvider.notifier,
          );

          store.putScope(_identity, _scope([_segment(7, 8)]));

          store.insertBeforeAnchor(_identity, 7, _segment(1, 4));

          final segments = container
              .read(conversationTimelineV2MessageStoreProvider)[_identity]!
              .segments;
          expect(_segmentIds(segments), [
            [1, 2, 3, 4, 7, 8],
          ]);
        },
      );

      test('replaces overlapping ranges across multiple cached segments', () {
        // Tests that one fresh before-anchor slice can bridge multiple cached
        // segments: stale overlap is removed, older prefix survives, and the
        // anchor-side suffix is preserved.
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final store = container.read(
          conversationTimelineV2MessageStoreProvider.notifier,
        );

        store.putScope(_identity, _scope([_segment(1, 3), _segment(4, 6)]));

        store.insertBeforeAnchor(_identity, 5, _segment(3, 4));

        final segments = container
            .read(conversationTimelineV2MessageStoreProvider)[_identity]!
            .segments;
        expect(_segmentIds(segments), [
          [1, 2],
          [3, 4, 5, 6],
        ]);
      });
      test('replace entire segments', () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final store = container.read(
          conversationTimelineV2MessageStoreProvider.notifier,
        );

        store.putScope(
          _identity,
          _scope([_segment(1, 3), _segment(4, 6), _segment(7, 9)]),
        );

        store.insertBeforeAnchor(_identity, 8, _segment(2, 7));

        final segments = container
            .read(conversationTimelineV2MessageStoreProvider)[_identity]!
            .segments;
        expect(_segmentIds(segments), [
          [1],
          [2, 3, 4, 5, 6, 7, 8, 9],
        ]);
      });
    });

    group('insertAfterAnchor', () {
      test('inserts the incoming segment into an empty scope', () {
        // Tests the base case: when nothing is cached yet, an after-anchor
        // fetch simply becomes the first cached segment.
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final store = container.read(
          conversationTimelineV2MessageStoreProvider.notifier,
        );

        store.insertAfterAnchor(_identity, 2, _segment(3, 4));

        final segments = container
            .read(conversationTimelineV2MessageStoreProvider)[_identity]!
            .segments;
        expect(_segmentIds(segments), [
          [3, 4],
        ]);
      });

      test('splits a segment that already contains the anchor', () {
        // Tests the main after-anchor refresh case: keep the stale anchor-side
        // prefix attached to the refreshed after-anchor interval, and preserve
        // the newer suffix as a trailing segment.
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final store = container.read(
          conversationTimelineV2MessageStoreProvider.notifier,
        );

        store.putScope(_identity, _scope([_segment(1, 5)]));

        store.insertAfterAnchor(_identity, 2, _segment(3, 4));

        final segments = container
            .read(conversationTimelineV2MessageStoreProvider)[_identity]!
            .segments;
        expect(_segmentIds(segments), [
          [1, 2, 3, 4],
          [5],
        ]);
      });

      test('split a segment', () {
        // Tests the symmetric split case: keep stale newer messages that fall
        // after the refreshed after-anchor interval as a separate suffix.
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final store = container.read(
          conversationTimelineV2MessageStoreProvider.notifier,
        );

        store.putScope(_identity, _scope([_segment(1, 6), _segment(9, 10)]));

        store.insertAfterAnchor(_identity, 3, _segment(4, 5));

        final segments = container
            .read(conversationTimelineV2MessageStoreProvider)[_identity]!
            .segments;
        expect(_segmentIds(segments), [
          [1, 2, 3, 4, 5],
          [6],
          [9, 10],
        ]);
      });

      test('split a segment / remove elements if needed', () {
        // Tests the symmetric removal case: stale messages between the anchor
        // and the fresh after-anchor slice are dropped, while later disjoint
        // history remains separate.
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final store = container.read(
          conversationTimelineV2MessageStoreProvider.notifier,
        );

        store.putScope(_identity, _scope([_segment(1, 2), _segment(5, 6)]));

        store.insertAfterAnchor(_identity, 1, _segment(3, 4));

        final segments = container
            .read(conversationTimelineV2MessageStoreProvider)[_identity]!
            .segments;
        expect(_segmentIds(segments), [
          [1, 3, 4],
          [5, 6],
        ]);
      });

      test(
        'keeps an older discontiguous segment before the refreshed slice',
        () {
          // Tests that a cached segment ending at the anchor becomes the
          // anchor-side continuation and attaches to the fresh after-anchor
          // slice, while truly newer segments remain separate.
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final store = container.read(
            conversationTimelineV2MessageStoreProvider.notifier,
          );

          store.putScope(_identity, _scope([_segment(1, 2), _segment(5, 6)]));

          store.insertAfterAnchor(_identity, 2, _segment(3, 4));

          final segments = container
              .read(conversationTimelineV2MessageStoreProvider)[_identity]!
              .segments;
          expect(_segmentIds(segments), [
            [1, 2, 3, 4],
            [5, 6],
          ]);
        },
      );

      test(
        'inserts after earlier segments that end at or before the anchor',
        () {
          // Tests that a cached segment ending at the anchor becomes the
          // anchor-side continuation and attaches to the fresh after-anchor
          // slice, even when there is no newer cached segment yet.
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final store = container.read(
            conversationTimelineV2MessageStoreProvider.notifier,
          );

          store.putScope(_identity, _scope([_segment(1, 2)]));

          store.insertAfterAnchor(_identity, 2, _segment(3, 4));

          final segments = container
              .read(conversationTimelineV2MessageStoreProvider)[_identity]!
              .segments;
          expect(_segmentIds(segments), [
            [1, 2, 3, 4],
          ]);
        },
      );

      test('replaces overlapping ranges across multiple cached segments', () {
        // Tests that one fresh after-anchor slice can bridge multiple cached
        // segments: the stale overlap is removed, the anchor-side prefix stays
        // attached to the fresh slice, and the newer suffix remains cached
        // after it.
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final store = container.read(
          conversationTimelineV2MessageStoreProvider.notifier,
        );

        store.putScope(_identity, _scope([_segment(1, 3), _segment(4, 6)]));

        store.insertAfterAnchor(_identity, 2, _segment(3, 4));

        final segments = container
            .read(conversationTimelineV2MessageStoreProvider)[_identity]!
            .segments;
        expect(_segmentIds(segments), [
          [1, 2, 3, 4],
          [5, 6],
        ]);
      });
    });

    group('insertAround', () {
      test('inserts the incoming segment into an empty scope', () {
        // Tests the base case: when nothing is cached yet, an around fetch
        // simply becomes the first cached segment.
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final store = container.read(
          conversationTimelineV2MessageStoreProvider.notifier,
        );

        store.insertAround(_identity, _segment(3, 4));

        final segments = container
            .read(conversationTimelineV2MessageStoreProvider)[_identity]!
            .segments;
        expect(_segmentIds(segments), [
          [3, 4],
        ]);
      });

      test('splits a segment that overlaps the incoming range', () {
        // Tests the main around-refresh case: keep the stale prefix and suffix
        // outside the refreshed interval, and replace the covered range with
        // the incoming slice.
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final store = container.read(
          conversationTimelineV2MessageStoreProvider.notifier,
        );

        store.putScope(_identity, _scope([_segment(1, 5)]));

        store.insertAround(_identity, _segment(3, 4));

        final segments = container
            .read(conversationTimelineV2MessageStoreProvider)[_identity]!
            .segments;
        expect(_segmentIds(segments), [
          [1, 2],
          [3, 4],
          [5],
        ]);
      });

      test(
        'keeps discontiguous segments on both sides of the refreshed range',
        () {
          // Tests that cached segments fully before and fully after the incoming
          // interval remain untouched and ordered around the fresh slice.
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final store = container.read(
            conversationTimelineV2MessageStoreProvider.notifier,
          );

          store.putScope(_identity, _scope([_segment(1, 2), _segment(5, 6)]));

          store.insertAround(_identity, _segment(3, 4));

          final segments = container
              .read(conversationTimelineV2MessageStoreProvider)[_identity]!
              .segments;
          expect(_segmentIds(segments), [
            [1, 2],
            [3, 4],
            [5, 6],
          ]);
        },
      );

      test('inserts between discontiguous cached segments without overlap', () {
        // Tests that a fresh around-range with no overlap is inserted into the
        // correct ordered position between existing cached segments.
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final store = container.read(
          conversationTimelineV2MessageStoreProvider.notifier,
        );

        store.putScope(_identity, _scope([_segment(1, 2), _segment(7, 8)]));

        store.insertAround(_identity, _segment(4, 5));

        final segments = container
            .read(conversationTimelineV2MessageStoreProvider)[_identity]!
            .segments;
        expect(_segmentIds(segments), [
          [1, 2],
          [4, 5],
          [7, 8],
        ]);
      });

      test('replaces overlapping ranges across multiple cached segments', () {
        // Tests that one fresh around-range can bridge multiple cached
        // segments: stale overlap is removed and untouched outer ranges stay
        // as separate cached segments.
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final store = container.read(
          conversationTimelineV2MessageStoreProvider.notifier,
        );

        store.putScope(_identity, _scope([_segment(1, 3), _segment(4, 6)]));

        store.insertAround(_identity, _segment(3, 4));

        final segments = container
            .read(conversationTimelineV2MessageStoreProvider)[_identity]!
            .segments;
        expect(_segmentIds(segments), [
          [1, 2],
          [3, 4],
          [5, 6],
        ]);
      });

      test('replaces entire segments', () {
        // Tests that one fresh around-range can bridge multiple cached
        // segments: stale overlap is removed and untouched outer ranges stay
        // as separate cached segments.
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final store = container.read(
          conversationTimelineV2MessageStoreProvider.notifier,
        );

        store.putScope(_identity, _scope([_segment(1, 3), _segment(4, 6)]));

        store.insertAround(_identity, _segment(1, 10));

        final segments = container
            .read(conversationTimelineV2MessageStoreProvider)[_identity]!
            .segments;
        expect(_segmentIds(segments), [
          [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
        ]);
      });
    });

    group('insertLatest', () {
      test('inserts the incoming segment into an empty scope', () {
        // Tests the base case: when nothing is cached yet, a latest fetch
        // becomes the first cached segment and is marked as the latest segment.
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final store = container.read(
          conversationTimelineV2MessageStoreProvider.notifier,
        );

        store.insertLatest(_identity, _segment(3, 4));

        final scope = container.read(
          conversationTimelineV2MessageStoreProvider,
        )[_identity]!;
        expect(_segmentIds(scope.segments), [
          [3, 4],
        ]);
        expect(scope.hasLatestSegment, true);
      });

      test('splits a segment that overlaps the incoming range', () {
        // Tests that latest insertion uses the same replacement rules as
        // around-insertion while pointing the latest marker at the fresh slice.
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final store = container.read(
          conversationTimelineV2MessageStoreProvider.notifier,
        );

        store.putScope(_identity, _scope([_segment(1, 5)]));

        store.insertLatest(_identity, _segment(3, 4));

        final scope = container.read(
          conversationTimelineV2MessageStoreProvider,
        )[_identity]!;
        expect(_segmentIds(scope.segments), [
          [1, 2],
          [3, 4],
        ]);
        expect(scope.hasLatestSegment, true);
      });

      test('push new segment at end', () {
        // Tests that latest insertion uses the same replacement rules as
        // around-insertion while pointing the latest marker at the fresh slice.
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final store = container.read(
          conversationTimelineV2MessageStoreProvider.notifier,
        );

        store.putScope(_identity, _scope([_segment(1, 5)]));

        store.insertLatest(_identity, _segment(7, 10));

        final scope = container.read(
          conversationTimelineV2MessageStoreProvider,
        )[_identity]!;
        expect(_segmentIds(scope.segments), [
          [1, 2, 3, 4, 5],
          [7, 8, 9, 10],
        ]);
        expect(scope.hasLatestSegment, true);
      });

      test(
        'keeps discontiguous segments on both sides of the refreshed range',
        () {
          // Tests that untouched cached segments remain around the fresh latest
          // slice while the latest marker points at the inserted segment.
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final store = container.read(
            conversationTimelineV2MessageStoreProvider.notifier,
          );

          store.putScope(_identity, _scope([_segment(1, 2), _segment(5, 6)]));

          store.insertLatest(_identity, _segment(3, 4));

          final scope = container.read(
            conversationTimelineV2MessageStoreProvider,
          )[_identity]!;
          expect(_segmentIds(scope.segments), [
            [1, 2],
            [3, 4],
          ]);
          expect(scope.hasLatestSegment, true);
        },
      );

      test('inserts between discontiguous cached segments without overlap', () {
        // Tests that a latest segment with no overlap is inserted in order and
        // becomes the explicitly tracked latest segment.
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final store = container.read(
          conversationTimelineV2MessageStoreProvider.notifier,
        );

        store.putScope(_identity, _scope([_segment(1, 2), _segment(7, 8)]));

        store.insertLatest(_identity, _segment(4, 5));

        final scope = container.read(
          conversationTimelineV2MessageStoreProvider,
        )[_identity]!;
        expect(_segmentIds(scope.segments), [
          [1, 2],
          [4, 5],
        ]);
        expect(scope.hasLatestSegment, true);
      });

      test('replaces overlapping ranges across multiple cached segments', () {
        // Tests that a latest segment can bridge multiple cached segments and
        // the latest marker follows the merged fresh range.
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final store = container.read(
          conversationTimelineV2MessageStoreProvider.notifier,
        );

        store.putScope(_identity, _scope([_segment(1, 3), _segment(4, 6)]));

        store.insertLatest(_identity, _segment(3, 4));

        final scope = container.read(
          conversationTimelineV2MessageStoreProvider,
        )[_identity]!;
        expect(_segmentIds(scope.segments), [
          [1, 2],
          [3, 4],
        ]);
        expect(scope.hasLatestSegment, true);
      });

      test('replaces entire segments', () {
        // Tests that a latest insertion can replace the whole cached span and
        // still leaves the latest marker pointing at the single merged segment.
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final store = container.read(
          conversationTimelineV2MessageStoreProvider.notifier,
        );

        store.putScope(_identity, _scope([_segment(1, 3), _segment(4, 6)]));

        store.insertLatest(_identity, _segment(1, 10));

        final scope = container.read(
          conversationTimelineV2MessageStoreProvider,
        )[_identity]!;
        expect(_segmentIds(scope.segments), [
          [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
        ]);
        expect(scope.hasLatestSegment, true);
      });
    });
  });
}

ConversationTimelineV2CanonicalSegment _segment(int start, int end) {
  return ConversationTimelineV2CanonicalSegment(
    orderedMessages: [for (var id = start; id <= end; id++) _message(id)],
  );
}

ConversationMessageV2 _message(int? serverMessageId) {
  return ConversationMessageV2(
    serverMessageId: serverMessageId,
    clientGeneratedId: 'client-${serverMessageId ?? 'missing'}',
    sender: _sender,
    content: TextMessageContent(text: 'message-$serverMessageId'),
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

ConversationTimelineV2CanonicalScope _scope(
  List<ConversationTimelineV2CanonicalSegment> segments, {
  bool hasLatestSegment = false,
}) {
  return (segments: segments, hasLatestSegment: hasLatestSegment);
}
