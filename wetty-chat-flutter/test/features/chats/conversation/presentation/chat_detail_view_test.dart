import 'package:flutter_test/flutter_test.dart';

import 'package:chahua/features/chats/conversation/application/conversation_timeline_view_model.dart';
import 'package:chahua/features/chats/conversation/domain/timeline_entry.dart';
import 'package:chahua/features/chats/conversation/domain/viewport_placement.dart';
import 'package:chahua/features/chats/conversation/presentation/timeline/jump_to_latest_fab.dart';

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

    test('shows FAB when newer pages can still be loaded away from live edge', () {
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
        shouldShowJumpToLatestFab(state: state, isAtLiveEdge: false),
        isTrue,
      );
    });

    test(
      'hides FAB when pending count exists but viewport is at live edge',
      () {
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
          isFalse,
        );
      },
    );
  });
}
