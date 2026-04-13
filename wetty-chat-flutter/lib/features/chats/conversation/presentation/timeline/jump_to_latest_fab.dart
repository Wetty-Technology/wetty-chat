import 'package:flutter/cupertino.dart';

import '../../../../../app/theme/style_config.dart';
import '../../application/conversation_timeline_view_model.dart';

bool shouldShowJumpToLatestFab({
  required ConversationTimelineState state,
  required bool isAtLiveEdge,
}) {
  if (isAtLiveEdge) {
    return false;
  }
  if (state.pendingLiveCount > 0) {
    return true;
  }
  if (state.canLoadNewer) {
    return true;
  }
  return true;
}

class JumpToLatestFab extends StatelessWidget {
  const JumpToLatestFab({
    super.key,
    required this.pendingLiveCount,
    required this.onPressed,
  });

  final int pendingLiveCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: CupertinoColors.systemGrey5.resolveFrom(context),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(CupertinoIcons.chevron_down),
            if (pendingLiveCount > 0)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Text(
                  '$pendingLiveCount',
                  style: appTextStyle(context, fontSize: AppFontSizes.meta),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
