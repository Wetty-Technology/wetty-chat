import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show CircularProgressIndicator;

import 'package:chahua/features/chats/conversation_v2/application/conversation_composer_view_model.dart';

enum ComposerAudioSnapPosition { origin, left, top }

enum ComposerAudioDragAxis { undecided, horizontal, vertical }

class ComposerAudioControls extends StatelessWidget {
  const ComposerAudioControls({
    super.key,
    required this.showAudioRecordButton,
    required this.showAudioTargets,
    required this.isSavedDraftPhase,
    required this.snapPosition,
    required this.dragOffset,
    required this.composer,
    required this.buttonSize,
    required this.slotWidth,
    required this.onSendRecordedAudio,
    required this.onAudioPointerDown,
    required this.onAudioPointerMove,
    required this.onAudioPointerFinish,
  });

  final bool showAudioRecordButton;
  final bool showAudioTargets;
  final bool isSavedDraftPhase;
  final ConversationComposerState composer;
  final ComposerAudioSnapPosition snapPosition;
  final Offset dragOffset;
  final double buttonSize;
  final double slotWidth;
  final Future<void> Function() onSendRecordedAudio;
  final ValueChanged<PointerDownEvent> onAudioPointerDown;
  final ValueChanged<PointerMoveEvent> onAudioPointerMove;
  final ValueChanged<PointerEvent> onAudioPointerFinish;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: slotWidth,
      height: buttonSize,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: showAudioRecordButton
            ? _AudioRecordButton(
                isActive: showAudioTargets,
                size: buttonSize,
                snapPosition: snapPosition,
                dragOffset: dragOffset,
                buttonChild: const Icon(
                  CupertinoIcons.mic_fill,
                  size: 20,
                  color: CupertinoColors.white,
                ),
                onPressed: null,
                onPointerDown: onAudioPointerDown,
                onPointerMove: onAudioPointerMove,
                onPointerFinish: onAudioPointerFinish,
              )
            : isSavedDraftPhase
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size(buttonSize, buttonSize),
                onPressed: composer.hasUploadingAudioDraft
                    ? null
                    : onSendRecordedAudio,
                child: Container(
                  width: buttonSize,
                  height: buttonSize,
                  decoration: BoxDecoration(
                    color: composer.hasUploadingAudioDraft
                        ? CupertinoColors.systemGrey3.resolveFrom(context)
                        : CupertinoColors.activeBlue.resolveFrom(context),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: composer.hasUploadingAudioDraft
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                CupertinoColors.white,
                              ),
                            ),
                          )
                        : const Icon(
                            CupertinoIcons.paperplane_fill,
                            size: 20,
                            color: CupertinoColors.white,
                          ),
                  ),
                ),
              )
            : CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size(buttonSize, buttonSize),
                onPressed: composer.canSend ? onSendRecordedAudio : null,
                child: Container(
                  width: buttonSize,
                  height: buttonSize,
                  decoration: BoxDecoration(
                    color: composer.canSend
                        ? CupertinoColors.activeBlue.resolveFrom(context)
                        : CupertinoColors.systemGrey3.resolveFrom(context),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.paperplane_fill,
                    size: 20,
                    color: CupertinoColors.white,
                  ),
                ),
              ),
      ),
    );
  }
}

class _AudioRecordButton extends StatelessWidget {
  const _AudioRecordButton({
    required this.isActive,
    required this.size,
    required this.snapPosition,
    required this.dragOffset,
    required this.buttonChild,
    required this.onPressed,
    required this.onPointerDown,
    required this.onPointerMove,
    required this.onPointerFinish,
  });

  static const double _targetGap = 18;

  final bool isActive;
  final double size;
  final ComposerAudioSnapPosition snapPosition;
  final Offset dragOffset;
  final Widget buttonChild;
  final VoidCallback? onPressed;
  final ValueChanged<PointerDownEvent> onPointerDown;
  final ValueChanged<PointerMoveEvent> onPointerMove;
  final ValueChanged<PointerEvent> onPointerFinish;

  @override
  Widget build(BuildContext context) {
    final active = snapPosition != ComposerAudioSnapPosition.origin;
    final icon = switch (snapPosition) {
      ComposerAudioSnapPosition.left => CupertinoIcons.delete,
      ComposerAudioSnapPosition.top => CupertinoIcons.arrow_up,
      ComposerAudioSnapPosition.origin => CupertinoIcons.mic_fill,
    };

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 120),
            left: -(size + _targetGap),
            top: 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              opacity: isActive ? 1 : 0,
              child: IgnorePointer(
                ignoring: !isActive,
                child: _AudioGestureTarget(
                  size: size,
                  icon: CupertinoIcons.delete,
                  active: snapPosition == ComposerAudioSnapPosition.left,
                ),
              ),
            ),
          ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 120),
            left: 0,
            top: -(size + _targetGap),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 120),
              opacity: isActive ? 1 : 0,
              child: IgnorePointer(
                ignoring: !isActive,
                child: _AudioGestureTarget(
                  size: size,
                  icon: CupertinoIcons.arrow_up,
                  active: snapPosition == ComposerAudioSnapPosition.top,
                ),
              ),
            ),
          ),
          Listener(
            onPointerDown: onPointerDown,
            onPointerMove: onPointerMove,
            onPointerUp: onPointerFinish,
            onPointerCancel: onPointerFinish,
            child: Transform.translate(
              offset: dragOffset,
              child: CupertinoButton(
                padding: EdgeInsets.zero,
                minimumSize: Size(size, size),
                onPressed: onPressed,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: snapPosition == ComposerAudioSnapPosition.left
                        ? CupertinoColors.systemRed.resolveFrom(context)
                        : CupertinoColors.activeBlue.resolveFrom(context),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:
                            (snapPosition == ComposerAudioSnapPosition.left
                                    ? CupertinoColors.systemRed
                                    : CupertinoColors.activeBlue)
                                .withAlpha(active ? 90 : 80),
                        blurRadius: active ? 16 : 10,
                        spreadRadius: active ? 1 : 0,
                      ),
                    ],
                  ),
                  child: Center(
                    child: active
                        ? Icon(icon, size: 20, color: CupertinoColors.white)
                        : buttonChild,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioGestureTarget extends StatelessWidget {
  const _AudioGestureTarget({
    required this.size,
    required this.icon,
    required this.active,
  });

  final double size;
  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: active
            ? icon == CupertinoIcons.delete
                  ? CupertinoColors.systemRed.resolveFrom(context)
                  : CupertinoColors.activeBlue.resolveFrom(context)
            : CupertinoColors.systemGrey4.resolveFrom(context),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 20,
        color: active
            ? CupertinoColors.white
            : CupertinoColors.systemGrey.resolveFrom(context),
      ),
    );
  }
}
