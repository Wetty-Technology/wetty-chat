import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

/// V2 copy of `ConversationBottomRegion`, simplified for v2's current feature
/// set (no sticker picker yet). Paints the composer surface with a top border
/// and reserves space at the bottom for the keyboard or safe-area inset —
/// whichever is larger — matching v1's visual behavior.
class ConversationV2BottomRegion extends StatelessWidget {
  const ConversationV2BottomRegion({
    super.key,
    required this.surfaceColor,
    required this.borderColor,
    required this.composer,
  });

  final Color surfaceColor;
  final Color borderColor;
  final Widget composer;

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    // viewPadding is the raw hardware safe-area (e.g. home indicator) that is
    // never reduced by ancestor SafeAreas or by viewInsets. Using it here
    // means we stay robust even if an ancestor consumes padding.
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final bottomInset = math.max(viewInsets.bottom, viewPadding.bottom);

    return ColoredBox(
      color: surfaceColor,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: borderColor)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [composer, SizedBox(height: bottomInset)],
        ),
      ),
    );
  }
}
