import 'package:flutter_test/flutter_test.dart';

import 'package:wetty_chat_flutter/features/chats/conversation/presentation/anchored_timeline_view.dart';

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
}
