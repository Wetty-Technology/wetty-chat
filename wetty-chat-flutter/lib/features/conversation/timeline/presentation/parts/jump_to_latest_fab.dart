import 'package:flutter/cupertino.dart';

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
                child: Text('$pendingLiveCount'),
              ),
          ],
        ),
      ),
    );
  }
}
