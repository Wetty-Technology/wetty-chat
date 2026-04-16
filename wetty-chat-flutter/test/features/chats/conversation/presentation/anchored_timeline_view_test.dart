import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chahua/features/chats/conversation/presentation/anchored_timeline_view.dart';
import 'package:chahua/features/chats/conversation/domain/conversation_message.dart';
import 'package:chahua/features/chats/conversation/domain/conversation_scope.dart';
import 'package:chahua/features/chats/conversation/domain/timeline_entry.dart';
import 'package:chahua/features/chats/conversation/domain/viewport_placement.dart';
import 'package:chahua/features/chats/models/message_models.dart';

void main() {
  group('resolveTopPreferredAnchorAlignment', () {
    test('pins to top when trailing extent fills the viewport', () {
      expect(
        resolveTopPreferredAnchorAlignment(
          afterExtent: 600,
          viewportExtent: 400,
        ),
        0.0,
      );
    });

    test(
      'clamps downward when trailing extent is smaller than the viewport',
      () {
        expect(
          resolveTopPreferredAnchorAlignment(
            afterExtent: 100,
            viewportExtent: 400,
          ),
          closeTo(0.75, 0.001),
        );
      },
    );

    test('falls back to top when viewport extent is invalid', () {
      expect(
        resolveTopPreferredAnchorAlignment(afterExtent: 100, viewportExtent: 0),
        0.0,
      );
    });
  });

  testWidgets(
    'top-preferred alignment recomputes when the effective anchor changes',
    (tester) async {
      final firstEntries = _entriesForAnchorTest(
        anchorId: 2,
        trailingHeight: 60,
      );
      final secondEntries = _entriesForAnchorTest(
        anchorId: 20,
        trailingHeight: 420,
      );

      await tester.pumpWidget(
        _buildTimelineTestApp(entries: firstEntries, anchorIndex: 1),
      );
      await tester.pump();
      await tester.pump();

      final firstAnchorTop = tester
          .getTopLeft(find.byKey(const ValueKey('entry-server:2')))
          .dy;

      await tester.pumpWidget(
        _buildTimelineTestApp(entries: secondEntries, anchorIndex: 1),
      );
      await tester.pump();
      await tester.pump();

      final secondAnchorTop = tester
          .getTopLeft(find.byKey(const ValueKey('entry-server:20')))
          .dy;

      expect(secondAnchorTop, lessThan(firstAnchorTop - 40));
    },
  );
}

Widget _buildTimelineTestApp({
  required List<TimelineEntry> entries,
  required int anchorIndex,
}) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: SizedBox(
        width: 300,
        height: 400,
        child: AnchoredTimelineView(
          entries: entries,
          anchorIndex: anchorIndex,
          viewportPlacement: ConversationViewportPlacement.topPreferred,
          entryBuilder: (context, entry, _) {
            final message = (entry as TimelineMessageEntry).message;
            final height = int.parse(message.message!).toDouble();
            return SizedBox(
              key: ValueKey('entry-${message.stableKey}'),
              height: height,
              child: Text(message.message!),
            );
          },
        ),
      ),
    ),
  );
}

List<TimelineEntry> _entriesForAnchorTest({
  required int anchorId,
  required double trailingHeight,
}) {
  return <TimelineEntry>[
    TimelineMessageEntry(_message(id: anchorId - 1, height: 40)),
    TimelineMessageEntry(_message(id: anchorId, height: 40)),
    TimelineMessageEntry(_message(id: anchorId + 1, height: trailingHeight)),
  ];
}

ConversationMessage _message({required int id, required double height}) {
  return ConversationMessage(
    scope: const ConversationScope.chat(chatId: '1'),
    serverMessageId: id,
    clientGeneratedId: 'client-$id',
    sender: const Sender(uid: 1, name: 'Tester'),
    message: '${height.toInt()}',
  );
}
