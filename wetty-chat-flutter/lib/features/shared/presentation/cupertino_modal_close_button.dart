import 'package:flutter/cupertino.dart';

class CupertinoModalCloseButton extends StatelessWidget {
  const CupertinoModalCloseButton({
    super.key,
    required this.onPressed,
    required this.semanticLabel,
  });

  final VoidCallback onPressed;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size.square(44),
      onPressed: onPressed,
      child: Icon(
        CupertinoIcons.xmark,
        size: 20,
        color: CupertinoColors.label.resolveFrom(context),
        semanticLabel: semanticLabel,
      ),
    );
  }
}
