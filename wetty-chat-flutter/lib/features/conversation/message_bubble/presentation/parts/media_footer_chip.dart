import 'package:flutter/cupertino.dart';

class MediaFooterChip extends StatelessWidget {
  const MediaFooterChip({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: CupertinoColors.black.withAlpha(110),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}
