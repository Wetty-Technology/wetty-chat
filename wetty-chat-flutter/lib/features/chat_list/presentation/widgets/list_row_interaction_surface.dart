import 'package:flutter/cupertino.dart';

class ListRowInteractionSurface extends StatefulWidget {
  const ListRowInteractionSurface({
    super.key,
    required this.child,
    required this.isActive,
    this.onTap,
  });

  final Widget child;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  State<ListRowInteractionSurface> createState() =>
      _ListRowInteractionSurfaceState();
}

class _ListRowInteractionSurfaceState extends State<ListRowInteractionSurface> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      color: _backgroundColor(context),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
        onTapCancel: widget.onTap == null ? null : () => _setPressed(false),
        onTapUp: widget.onTap == null ? null : (_) => _setPressed(false),
        child: widget.child,
      ),
    );
  }

  void _setPressed(bool isPressed) {
    if (_isPressed == isPressed) {
      return;
    }
    setState(() => _isPressed = isPressed);
  }

  Color _backgroundColor(BuildContext context) {
    if (_isPressed) {
      return widget.isActive
          ? CupertinoColors.activeBlue.resolveFrom(context).withAlpha(38)
          : CupertinoColors.systemGrey5.resolveFrom(context);
    }
    if (widget.isActive) {
      return CupertinoColors.activeBlue.resolveFrom(context).withAlpha(25);
    }
    return CupertinoColors.systemBackground.resolveFrom(context);
  }
}
