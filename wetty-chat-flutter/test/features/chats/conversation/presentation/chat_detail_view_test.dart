import 'package:flutter_test/flutter_test.dart';

import 'package:wetty_chat_flutter/features/chats/conversation/application/conversation_timeline_view_model.dart';
import 'package:wetty_chat_flutter/features/chats/conversation/domain/timeline_entry.dart';
import 'package:wetty_chat_flutter/features/chats/conversation/domain/viewport_placement.dart';
import 'package:wetty_chat_flutter/features/chats/conversation/presentation/chat_detail_view.dart';

void main() {
  group('shouldShowJumpToLatestFab', () {
    test('hides FAB when anchored launch is already effectively at bottom', () {
      final state = ConversationTimelineState(
        entries: const <TimelineEntry>[],
        windowStableKeys: const <String>[],
        windowMode: ConversationWindowMode.anchoredTarget,
        viewportPlacement: ConversationViewportPlacement.topPreferred,
        canLoadOlder: true,
        canLoadNewer: false,
        anchorEntryIndex: 0,
      );

      expect(
        shouldShowJumpToLatestFab(state: state, isAtLiveEdge: true),
        isFalse,
      );
    });

    test('shows FAB when newer pages can still be loaded', () {
      final state = ConversationTimelineState(
        entries: const <TimelineEntry>[],
        windowStableKeys: const <String>[],
        windowMode: ConversationWindowMode.anchoredTarget,
        viewportPlacement: ConversationViewportPlacement.topPreferred,
        canLoadOlder: true,
        canLoadNewer: true,
        anchorEntryIndex: 0,
      );

      expect(
        shouldShowJumpToLatestFab(state: state, isAtLiveEdge: true),
        isTrue,
      );
    });

    test('shows FAB when pending live items exist even at live edge', () {
      final state = ConversationTimelineState(
        entries: const <TimelineEntry>[],
        windowStableKeys: const <String>[],
        windowMode: ConversationWindowMode.liveLatest,
        viewportPlacement: ConversationViewportPlacement.liveEdge,
        canLoadOlder: true,
        canLoadNewer: false,
        anchorEntryIndex: 0,
        pendingLiveCount: 3,
      );

      expect(
        shouldShowJumpToLatestFab(state: state, isAtLiveEdge: true),
        isTrue,
      );
    });
  });
}
