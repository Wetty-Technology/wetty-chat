import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/style_config.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/presentation/app_divider.dart';
import '../application/conversation_composer_view_model.dart';
import '../data/attachment_picker_service.dart';
import '../domain/conversation_scope.dart';
import 'widgets/composer_attachment_menu.dart';
import 'widgets/composer_audio_controls.dart';
import 'widgets/composer_input_area.dart';

class ConversationComposerBar extends ConsumerStatefulWidget {
  const ConversationComposerBar({
    super.key,
    required this.scope,
    this.onMessageSent,
  });

  final ConversationScope scope;
  final Future<void> Function()? onMessageSent;

  @override
  ConsumerState<ConversationComposerBar> createState() =>
      _ConversationComposerBarState();
}

class _ConversationComposerBarState
    extends ConsumerState<ConversationComposerBar> {
  static const double _audioGestureThreshold = 26;
  static const double _composerActionButtonSize = 36;
  static const double _composerActionSlotWidth = 48;
  static const double _composerFieldMinHeight = 36;
  static const double _audioGestureTargetGap = 18;
  final ScrollController _inputScrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final LayerLink _attachmentMenuLink = LayerLink();

  ProviderSubscription<ConversationComposerState>? _composerSubscription;
  bool _isAttachmentPanelOpen = false;
  OverlayEntry? _attachmentMenuEntry;
  int? _activeAudioPointerId;
  Offset? _audioPointerOrigin;
  ComposerAudioSnapPosition _audioSnapPosition =
      ComposerAudioSnapPosition.origin;
  Offset _audioDragOffset = Offset.zero;

  void _resetAudioGestureState() {
    _activeAudioPointerId = null;
    _audioPointerOrigin = null;
    _audioSnapPosition = ComposerAudioSnapPosition.origin;
    _audioDragOffset = Offset.zero;
  }

  @override
  void initState() {
    super.initState();
    _composerSubscription = ref.listenManual<ConversationComposerState>(
      conversationComposerViewModelProvider(widget.scope),
      (_, next) {
        _syncControllerText(next.draft);
        if (_isAttachmentPanelOpen &&
            (next.isEditing || next.isAtAttachmentLimit)) {
          _closeAttachmentMenu();
        }
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _closeAttachmentMenu(updateState: false);
    _composerSubscription?.close();
    _inputScrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _syncControllerText(String draft) {
    if (_textController.text == draft) {
      return;
    }
    _textController.value = TextEditingValue(
      text: draft,
      selection: TextSelection.collapsed(offset: draft.length),
    );
  }

  Future<void> _sendMessage() async {
    final composer = ref.read(
      conversationComposerViewModelProvider(widget.scope),
    );
    final composerNotifier = ref.read(
      conversationComposerViewModelProvider(widget.scope).notifier,
    );
    if (composer.isEditing && composer.attachments.isNotEmpty) {
      _showErrorDialog('Editing does not support attachments yet.');
      return;
    }
    if (_textController.text.trim().isEmpty &&
        !composer.hasUploadedAttachments) {
      return;
    }
    try {
      await composerNotifier.send(text: _textController.text);
      _closeAttachmentMenu();
      _textController.clear();
      await widget.onMessageSent?.call();
    } catch (error) {
      if (mounted) {
        _showErrorDialog('$error');
      }
    }
  }

  Future<void> _sendRecordedAudio() async {
    final composerNotifier = ref.read(
      conversationComposerViewModelProvider(widget.scope).notifier,
    );
    try {
      await composerNotifier.sendRecordedAudio();
      _closeAttachmentMenu();
      await widget.onMessageSent?.call();
    } on ComposerAudioException catch (error) {
      if (mounted) {
        _showErrorDialog(_audioErrorMessage(error));
      }
    } catch (error) {
      if (mounted) {
        _showErrorDialog('$error');
      }
    }
  }

  Future<void> _pickAttachments(ComposerAttachmentSource source) async {
    try {
      final message = await ref
          .read(conversationComposerViewModelProvider(widget.scope).notifier)
          .pickAndQueueAttachments(source);
      _closeAttachmentMenu();
      if (!mounted || message == null) {
        return;
      }
      _showErrorDialog(message);
    } catch (error) {
      if (mounted) {
        _showErrorDialog('$error');
      }
    }
  }

  void _toggleAttachmentPanel() {
    if (_isAttachmentPanelOpen) {
      _closeAttachmentMenu();
      return;
    }
    _openAttachmentMenu();
  }

  void _openAttachmentMenu() {
    final overlay = Overlay.of(context);
    _attachmentMenuEntry?.remove();
    _attachmentMenuEntry = OverlayEntry(
      builder: (overlayContext) {
        final screenWidth = MediaQuery.sizeOf(overlayContext).width;
        final maxWidth = screenWidth * 0.54;
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _closeAttachmentMenu,
              ),
            ),
            CompositedTransformFollower(
              link: _attachmentMenuLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomLeft,
              followerAnchor: Alignment.bottomLeft,
              offset: const Offset(0, 0),
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: 176,
                    maxWidth: maxWidth.clamp(176, 236),
                  ),
                  child: ComposerAttachmentMenu(
                    onPickAttachments: _pickAttachments,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    overlay.insert(_attachmentMenuEntry!);
    if (mounted) {
      setState(() {
        _isAttachmentPanelOpen = true;
      });
    }
  }

  void _closeAttachmentMenu({bool updateState = true}) {
    _attachmentMenuEntry?.remove();
    _attachmentMenuEntry = null;
    if (updateState && mounted && _isAttachmentPanelOpen) {
      setState(() {
        _isAttachmentPanelOpen = false;
      });
    } else if (!updateState) {
      _isAttachmentPanelOpen = false;
    }
  }

  void _showErrorDialog(String message) {
    final l10n = AppLocalizations.of(context)!;
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(l10n.error),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
  }

  String _audioErrorMessage(ComposerAudioException error) {
    final l10n = AppLocalizations.of(context)!;
    return switch (error.code) {
      ComposerAudioErrorCode.unsupported => l10n.voiceRecordingUnsupported,
      ComposerAudioErrorCode.permissionDenied =>
        l10n.voiceMicrophonePermissionDenied,
      ComposerAudioErrorCode.tooShort => l10n.voiceRecordingTooShort,
      ComposerAudioErrorCode.startFailed => l10n.voiceRecordingStartFailed,
      ComposerAudioErrorCode.uploadFailed => l10n.voiceMessageUploadFailed,
    };
  }

  ComposerAudioSnapPosition _resolveAudioSnapPosition(Offset currentPosition) {
    final origin = _audioPointerOrigin;
    if (origin == null) {
      return ComposerAudioSnapPosition.origin;
    }
    final dx = currentPosition.dx - origin.dx;
    final dy = currentPosition.dy - origin.dy;
    final leftProgress = -dx;
    final upProgress = -dy;
    final axis = _resolveAudioDragAxis(dx, dy);

    return switch (axis) {
      ComposerAudioDragAxis.horizontal =>
        leftProgress >= _audioGestureThreshold
            ? ComposerAudioSnapPosition.left
            : ComposerAudioSnapPosition.origin,
      ComposerAudioDragAxis.vertical =>
        upProgress >= _audioGestureThreshold
            ? ComposerAudioSnapPosition.top
            : ComposerAudioSnapPosition.origin,
      ComposerAudioDragAxis.undecided => ComposerAudioSnapPosition.origin,
    };
  }

  Future<void> _handleAudioPointerDown(PointerDownEvent event) async {
    if (_activeAudioPointerId != null) {
      return;
    }
    _activeAudioPointerId = event.pointer;
    _audioPointerOrigin = event.position;
    setState(() {
      _audioSnapPosition = ComposerAudioSnapPosition.origin;
      _audioDragOffset = Offset.zero;
    });
    try {
      await ref
          .read(conversationComposerViewModelProvider(widget.scope).notifier)
          .startAudioRecording();
    } on ComposerAudioException catch (error) {
      _resetAudioGestureState();
      if (mounted) {
        _showErrorDialog(_audioErrorMessage(error));
      }
    } catch (error) {
      _resetAudioGestureState();
      if (mounted) {
        _showErrorDialog('$error');
      }
    }
  }

  void _handleAudioPointerMove(PointerMoveEvent event) {
    if (_activeAudioPointerId != event.pointer) {
      return;
    }
    final visualOffset = _resolveAudioDragOffset(event.position);
    final next = _resolveAudioSnapPosition(event.position);
    if (next == _audioSnapPosition && visualOffset == _audioDragOffset) {
      return;
    }
    setState(() {
      _audioDragOffset = visualOffset;
      _audioSnapPosition = next;
    });
  }

  Offset _resolveAudioDragOffset(Offset currentPosition) {
    final origin = _audioPointerOrigin;
    if (origin == null) {
      return Offset.zero;
    }
    final maxOffset = _composerActionButtonSize + _audioGestureTargetGap;
    final dx = currentPosition.dx - origin.dx;
    final dy = currentPosition.dy - origin.dy;
    final nextAxis = _resolveAudioDragAxis(dx, dy);

    return switch (nextAxis) {
      ComposerAudioDragAxis.horizontal => Offset(dx.clamp(-maxOffset, 0.0), 0),
      ComposerAudioDragAxis.vertical => Offset(0, dy.clamp(-maxOffset, 0.0)),
      ComposerAudioDragAxis.undecided => Offset.zero,
    };
  }

  ComposerAudioDragAxis _resolveAudioDragAxis(double dx, double dy) {
    final leftProgress = -dx;
    final upProgress = -dy;
    final crossedLeft = leftProgress >= _audioGestureThreshold;
    final crossedTop = upProgress >= _audioGestureThreshold;

    if (!crossedLeft && !crossedTop) {
      return ComposerAudioDragAxis.undecided;
    }
    return leftProgress >= upProgress
        ? ComposerAudioDragAxis.horizontal
        : ComposerAudioDragAxis.vertical;
  }

  Future<void> _finalizeAudioGesture(ComposerAudioSnapPosition position) async {
    final composerNotifier = ref.read(
      conversationComposerViewModelProvider(widget.scope).notifier,
    );
    try {
      switch (position) {
        case ComposerAudioSnapPosition.left:
          await composerNotifier.cancelAudioRecording();
          break;
        case ComposerAudioSnapPosition.top:
          await composerNotifier.finishAudioRecording();
          await _sendRecordedAudio();
          break;
        case ComposerAudioSnapPosition.origin:
          await composerNotifier.finishAudioRecording();
          break;
      }
    } on ComposerAudioException catch (error) {
      if (mounted) {
        _showErrorDialog(_audioErrorMessage(error));
      }
    } catch (error) {
      if (mounted) {
        _showErrorDialog('$error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _resetAudioGestureState();
        });
      } else {
        _resetAudioGestureState();
      }
    }
  }

  Future<void> _handleAudioPointerFinish(PointerEvent event) async {
    if (_activeAudioPointerId != event.pointer) {
      return;
    }
    await _finalizeAudioGesture(_resolveAudioSnapPosition(event.position));
  }

  bool _isRecordingPhase(ConversationComposerState composer) {
    final draft = composer.audioDraft;
    if (draft == null) {
      return false;
    }
    return draft.phase == ComposerAudioDraftPhase.requestingPermission ||
        draft.phase == ComposerAudioDraftPhase.recording;
  }

  bool _isSavedDraftPhase(ConversationComposerState composer) {
    final draft = composer.audioDraft;
    if (draft == null) {
      return false;
    }
    return draft.phase == ComposerAudioDraftPhase.recorded ||
        draft.phase == ComposerAudioDraftPhase.uploading;
  }

  @override
  Widget build(BuildContext context) {
    final composer = ref.watch(
      conversationComposerViewModelProvider(widget.scope),
    );
    final colors = context.appColors;
    final selectionLocked = composer.isAtAttachmentLimit;
    final canAttach =
        !composer.isEditing &&
        !selectionLocked &&
        !composer.hasAudioDraft &&
        !composer.hasPendingAudioRecording;
    final isRecordingPhase = _isRecordingPhase(composer);
    final isSavedDraftPhase = _isSavedDraftPhase(composer);
    final showAudioRecordButton =
        !composer.canSend && (composer.canStartAudio || isRecordingPhase);
    final showAudioTargets = _activeAudioPointerId != null;

    return ColoredBox(
      color: colors.backgroundSecondary,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppDivider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Opacity(
                  opacity: selectionLocked ? 0.45 : 1,
                  child: CompositedTransformTarget(
                    link: _attachmentMenuLink,
                    child: SizedBox(
                      width: 36,
                      height: 36,
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(36, 36),
                        onPressed: canAttach ? _toggleAttachmentPanel : null,
                        child: Icon(
                          CupertinoIcons.add_circled,
                          color: canAttach
                              ? CupertinoColors.activeBlue.resolveFrom(context)
                              : CupertinoColors.systemGrey2.resolveFrom(
                                  context,
                                ),
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                ),
                if (composer.hasPendingAttachmentUploads)
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 2),
                    child: CupertinoActivityIndicator(radius: 8),
                  ),
                const SizedBox(width: 4),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: colors.inputBorder),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(19),
                      child: ColoredBox(
                        color: colors.backgroundSecondary,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ComposerInputArea(
                              composer: composer,
                              textController: _textController,
                              inputScrollController: _inputScrollController,
                              snapPosition: _audioSnapPosition,
                              fieldMinHeight: _composerFieldMinHeight,
                              onClearMode: () {
                                ref
                                    .read(
                                      conversationComposerViewModelProvider(
                                        widget.scope,
                                      ).notifier,
                                    )
                                    .clearMode();
                              },
                              onRemoveAttachment: (localId) {
                                ref
                                    .read(
                                      conversationComposerViewModelProvider(
                                        widget.scope,
                                      ).notifier,
                                    )
                                    .removeAttachment(localId);
                              },
                              onRetryAttachment: (localId) {
                                return ref
                                    .read(
                                      conversationComposerViewModelProvider(
                                        widget.scope,
                                      ).notifier,
                                    )
                                    .retryAttachment(localId);
                              },
                              onDeleteAudioDraft: () {
                                return ref
                                    .read(
                                      conversationComposerViewModelProvider(
                                        widget.scope,
                                      ).notifier,
                                    )
                                    .cancelAudioRecording();
                              },
                              onDraftChanged: (value) {
                                unawaited(
                                  ref
                                      .read(
                                        conversationComposerViewModelProvider(
                                          widget.scope,
                                        ).notifier,
                                      )
                                      .updateDraft(value),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                ComposerAudioControls(
                  showAudioRecordButton: showAudioRecordButton,
                  showAudioTargets: showAudioTargets,
                  isSavedDraftPhase: isSavedDraftPhase,
                  snapPosition: _audioSnapPosition,
                  dragOffset: _audioDragOffset,
                  composer: composer,
                  buttonSize: _composerActionButtonSize,
                  slotWidth: _composerActionSlotWidth,
                  onSendRecordedAudio:
                      showAudioRecordButton || isSavedDraftPhase
                      ? _sendRecordedAudio
                      : _sendMessage,
                  onAudioPointerDown: _handleAudioPointerDown,
                  onAudioPointerMove: _handleAudioPointerMove,
                  onAudioPointerFinish: _handleAudioPointerFinish,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
