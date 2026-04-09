import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show CircularProgressIndicator;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/style_config.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/presentation/app_divider.dart';
import '../../models/message_preview_formatter.dart';
import '../application/conversation_composer_view_model.dart';
import '../data/attachment_picker_service.dart';
import '../domain/conversation_scope.dart';

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
  final ScrollController _inputScrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  final LayerLink _attachmentMenuLink = LayerLink();

  ProviderSubscription<ConversationComposerState>? _composerSubscription;
  bool _isAttachmentPanelOpen = false;
  OverlayEntry? _attachmentMenuEntry;
  int? _activeAudioPointerId;
  Offset? _audioPointerOrigin;
  _AudioRecordSnapPosition _audioSnapPosition = _AudioRecordSnapPosition.origin;

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
                  child: _buildAttachmentMenu(),
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

  Widget _sourceAction({
    required String label,
    required ComposerAttachmentSource source,
    required bool showDivider,
  }) {
    final colors = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: colors.inputBorder))
            : null,
      ),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        onPressed: () => unawaited(_pickAttachments(source)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _sourceIcon(source),
              size: 24,
              color: CupertinoColors.activeBlue.resolveFrom(context),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.left,
                style: appTextStyle(
                  context,
                  fontWeight: FontWeight.w600,
                  fontSize: AppFontSizes.body,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _sourceIcon(ComposerAttachmentSource source) {
    return switch (source) {
      ComposerAttachmentSource.photos => CupertinoIcons.photo_on_rectangle,
      ComposerAttachmentSource.gifs => CupertinoIcons.sparkles,
      ComposerAttachmentSource.videos => CupertinoIcons.videocam_fill,
      ComposerAttachmentSource.files => CupertinoIcons.doc_fill,
    };
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

  _AudioRecordSnapPosition _resolveAudioSnapPosition(Offset currentPosition) {
    final origin = _audioPointerOrigin;
    if (origin == null) {
      return _AudioRecordSnapPosition.origin;
    }
    final dx = currentPosition.dx - origin.dx;
    final dy = currentPosition.dy - origin.dy;
    final leftProgress = -dx;
    final upProgress = -dy;
    final crossedLeft = leftProgress >= _audioGestureThreshold;
    final crossedTop = upProgress >= _audioGestureThreshold;

    if (!crossedLeft && !crossedTop) {
      return _AudioRecordSnapPosition.origin;
    }
    if (crossedLeft && crossedTop) {
      return leftProgress >= upProgress
          ? _AudioRecordSnapPosition.left
          : _AudioRecordSnapPosition.top;
    }
    return crossedLeft
        ? _AudioRecordSnapPosition.left
        : _AudioRecordSnapPosition.top;
  }

  Future<void> _handleAudioPointerDown(PointerDownEvent event) async {
    if (_activeAudioPointerId != null) {
      return;
    }
    _activeAudioPointerId = event.pointer;
    _audioPointerOrigin = event.position;
    setState(() {
      _audioSnapPosition = _AudioRecordSnapPosition.origin;
    });
    try {
      await ref
          .read(conversationComposerViewModelProvider(widget.scope).notifier)
          .startAudioRecording();
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

  void _handleAudioPointerMove(PointerMoveEvent event) {
    if (_activeAudioPointerId != event.pointer) {
      return;
    }
    final next = _resolveAudioSnapPosition(event.position);
    if (next == _audioSnapPosition) {
      return;
    }
    setState(() {
      _audioSnapPosition = next;
    });
  }

  Future<void> _finalizeAudioGesture(_AudioRecordSnapPosition position) async {
    final composerNotifier = ref.read(
      conversationComposerViewModelProvider(widget.scope).notifier,
    );
    try {
      switch (position) {
        case _AudioRecordSnapPosition.left:
          await composerNotifier.cancelAudioRecording();
          break;
        case _AudioRecordSnapPosition.top:
          await composerNotifier.finishAudioRecording();
          await _sendRecordedAudio();
          break;
        case _AudioRecordSnapPosition.origin:
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
          _activeAudioPointerId = null;
          _audioPointerOrigin = null;
          _audioSnapPosition = _AudioRecordSnapPosition.origin;
        });
      } else {
        _activeAudioPointerId = null;
        _audioPointerOrigin = null;
        _audioSnapPosition = _AudioRecordSnapPosition.origin;
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
    final l10n = AppLocalizations.of(context)!;
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
                            _buildComposerPreview(composer),
                            if (composer.attachments.isNotEmpty)
                              _buildAttachmentPreview(composer),
                            ConstrainedBox(
                              constraints: const BoxConstraints(
                                minHeight: _composerFieldMinHeight,
                              ),
                              child: isRecordingPhase
                                  ? _VoiceDraftPanel(
                                      draft: composer.audioDraft!,
                                      snapPosition: _audioSnapPosition,
                                      onDelete: null,
                                      showDelete: false,
                                    )
                                  : isSavedDraftPhase
                                  ? _VoiceDraftPanel(
                                      draft: composer.audioDraft!,
                                      snapPosition: _audioSnapPosition,
                                      onDelete: composer.hasUploadingAudioDraft
                                          ? null
                                          : () {
                                              unawaited(
                                                ref
                                                    .read(
                                                      conversationComposerViewModelProvider(
                                                        widget.scope,
                                                      ).notifier,
                                                    )
                                                    .cancelAudioRecording(),
                                              );
                                            },
                                      showDelete: true,
                                    )
                                  : CupertinoScrollbar(
                                      controller: _inputScrollController,
                                      child: CupertinoTextField(
                                        controller: _textController,
                                        scrollController:
                                            _inputScrollController,
                                        onChanged: (value) {
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
                                        placeholder: l10n.message,
                                        maxLines: 5,
                                        minLines: 1,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        decoration: null,
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: _composerActionSlotWidth,
                  height: _composerActionButtonSize,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: showAudioRecordButton
                        ? _AudioRecordButton(
                            isActive: showAudioTargets,
                            size: _composerActionButtonSize,
                            snapPosition: _audioSnapPosition,
                            buttonChild: const Icon(
                              CupertinoIcons.mic_fill,
                              size: 20,
                              color: CupertinoColors.white,
                            ),
                            onPressed: null,
                            onPointerDown: _handleAudioPointerDown,
                            onPointerMove: _handleAudioPointerMove,
                            onPointerFinish: _handleAudioPointerFinish,
                          )
                        : isSavedDraftPhase
                        ? CupertinoButton(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(
                              _composerActionButtonSize,
                              _composerActionButtonSize,
                            ),
                            onPressed: composer.hasUploadingAudioDraft
                                ? null
                                : _sendRecordedAudio,
                            child: Container(
                              width: _composerActionButtonSize,
                              height: _composerActionButtonSize,
                              decoration: BoxDecoration(
                                color: composer.hasUploadingAudioDraft
                                    ? CupertinoColors.systemGrey3.resolveFrom(
                                        context,
                                      )
                                    : CupertinoColors.activeBlue.resolveFrom(
                                        context,
                                      ),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: composer.hasUploadingAudioDraft
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
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
                            minimumSize: const Size(
                              _composerActionButtonSize,
                              _composerActionButtonSize,
                            ),
                            onPressed: composer.canSend ? _sendMessage : null,
                            child: Container(
                              width: _composerActionButtonSize,
                              height: _composerActionButtonSize,
                              decoration: BoxDecoration(
                                color: composer.canSend
                                    ? CupertinoColors.activeBlue.resolveFrom(
                                        context,
                                      )
                                    : CupertinoColors.systemGrey3.resolveFrom(
                                        context,
                                      ),
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentMenu() {
    final colors = context.appColors;

    return CupertinoPopupSurface(
      isSurfacePainted: false,
      child: Container(
        key: const ValueKey<String>('attachment-panel'),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.composerReplyPreviewSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.inputBorder.withAlpha(230)),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withAlpha(22),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
            BoxShadow(
              color: CupertinoColors.black.withAlpha(34),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sourceAction(
              label: AppLocalizations.of(context)!.photos,
              source: ComposerAttachmentSource.photos,
              showDivider: true,
            ),
            _sourceAction(
              label: AppLocalizations.of(context)!.gifs,
              source: ComposerAttachmentSource.gifs,
              showDivider: true,
            ),
            _sourceAction(
              label: AppLocalizations.of(context)!.videos,
              source: ComposerAttachmentSource.videos,
              showDivider: true,
            ),
            _sourceAction(
              label: AppLocalizations.of(context)!.files,
              source: ComposerAttachmentSource.files,
              showDivider: false,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposerPreview(ConversationComposerState composer) {
    final mode = composer.mode;
    return switch (mode) {
      ComposerReplying(:final message) => _previewBar(
        title:
            '${AppLocalizations.of(context)!.reply} ${message.sender.name ?? 'User ${message.sender.uid}'}',
        body: formatMessagePreview(
          message: message.message,
          messageType: message.messageType,
          sticker: message.sticker,
          attachments: message.attachments,
          firstAttachmentKind: message.attachments.isNotEmpty
              ? message.attachments.first.kind
              : null,
          isDeleted: message.isDeleted,
          mentions: message.mentions,
        ),
      ),
      ComposerEditing(:final message) => _previewBar(
        title: AppLocalizations.of(context)!.edit,
        body: formatMessagePreview(
          message: message.message,
          messageType: message.messageType,
          sticker: message.sticker,
          attachments: message.attachments,
          firstAttachmentKind: message.attachments.isNotEmpty
              ? message.attachments.first.kind
              : null,
          isDeleted: message.isDeleted,
          mentions: message.mentions,
        ),
      ),
      ComposerIdle() => const SizedBox.shrink(),
    };
  }

  Widget _previewBar({required String title, required String body}) {
    final colors = context.appColors;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 4),
      decoration: BoxDecoration(
        color: colors.composerReplyPreviewSurface,
        border: Border(
          bottom: BorderSide(color: colors.composerReplyPreviewDivider),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appTextStyle(
                    context,
                    fontWeight: FontWeight.w600,
                    fontSize: AppFontSizes.meta,
                    color: colors.composerReplyPreviewTitle,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appSecondaryTextStyle(
                    context,
                    fontSize: AppFontSizes.meta,
                  ),
                ),
              ],
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(30, 30),
            onPressed: () {
              ref
                  .read(
                    conversationComposerViewModelProvider(
                      widget.scope,
                    ).notifier,
                  )
                  .clearMode();
            },
            child: Icon(
              CupertinoIcons.xmark_circle_fill,
              size: 18,
              color: colors.inactive,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentPreview(ConversationComposerState composer) {
    final colors = context.appColors;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.inputBorder)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final attachment in composer.attachments)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _attachmentCard(attachment),
              ),
          ],
        ),
      ),
    );
  }

  Widget _attachmentCard(ComposerAttachment attachment) {
    final borderColor = CupertinoColors.systemGrey4.resolveFrom(context);
    return Container(
      width: 116,
      height: 116,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.black.withAlpha(26),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _attachmentPreviewThumb(attachment),
          Positioned(
            top: 6,
            right: 6,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(28, 28),
              onPressed: () {
                ref
                    .read(
                      conversationComposerViewModelProvider(
                        widget.scope,
                      ).notifier,
                    )
                    .removeAttachment(attachment.localId);
              },
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: CupertinoColors.black.withAlpha(150),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.xmark,
                  size: 16,
                  color: CupertinoColors.white,
                ),
              ),
            ),
          ),
          if (attachment.isQueued || attachment.isUploading)
            _progressOverlay(attachment)
          else if (attachment.isFailed)
            _errorOverlay(attachment),
        ],
      ),
    );
  }

  Widget _attachmentPreviewThumb(ComposerAttachment attachment) {
    final background = CupertinoColors.systemGrey4.resolveFrom(context);
    final icon = switch (attachment.kind) {
      ComposerAttachmentKind.video => CupertinoIcons.play_rectangle_fill,
      ComposerAttachmentKind.file => CupertinoIcons.doc_fill,
      _ => CupertinoIcons.photo_fill,
    };

    if (attachment.previewBytes != null) {
      return Image.memory(attachment.previewBytes!, fit: BoxFit.cover);
    }

    return DecoratedBox(
      decoration: BoxDecoration(color: background),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: CupertinoColors.white),
              const SizedBox(height: 8),
              Text(
                attachment.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: appTextStyle(
                  context,
                  fontSize: AppFontSizes.meta,
                  color: CupertinoColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _progressOverlay(ComposerAttachment attachment) {
    final progressValue = attachment.progress > 0 ? attachment.progress : null;
    final progressLabel = '${(attachment.progress * 100).round()}%';
    return Container(
      color: CupertinoColors.black.withAlpha(135),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 54,
            height: 54,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progressValue,
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    CupertinoColors.white,
                  ),
                  backgroundColor: CupertinoColors.white.withAlpha(64),
                ),
                Text(
                  progressValue == null ? '...' : progressLabel,
                  style: appTextStyle(
                    context,
                    fontSize: AppFontSizes.meta,
                    color: CupertinoColors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorOverlay(ComposerAttachment attachment) {
    return Container(
      color: const Color(0xC27F1D1D),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            CupertinoIcons.exclamationmark_circle_fill,
            size: 28,
            color: CupertinoColors.white,
          ),
          const SizedBox(height: 8),
          Text(
            attachment.errorMessage ?? 'Upload failed',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: appTextStyle(
              context,
              fontSize: AppFontSizes.meta,
              color: CupertinoColors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: const Size(28, 28),
            color: CupertinoColors.white.withAlpha(36),
            borderRadius: BorderRadius.circular(999),
            onPressed: () {
              unawaited(
                ref
                    .read(
                      conversationComposerViewModelProvider(
                        widget.scope,
                      ).notifier,
                    )
                    .retryAttachment(attachment.localId),
              );
            },
            child: Text(
              'Retry',
              style: appTextStyle(
                context,
                fontSize: AppFontSizes.meta,
                color: CupertinoColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _AudioRecordSnapPosition { origin, left, top }

class _AudioRecordButton extends StatelessWidget {
  const _AudioRecordButton({
    required this.isActive,
    required this.size,
    required this.snapPosition,
    required this.buttonChild,
    required this.onPressed,
    required this.onPointerDown,
    required this.onPointerMove,
    required this.onPointerFinish,
  });

  static const double _targetGap = 18;

  final bool isActive;
  final double size;
  final _AudioRecordSnapPosition snapPosition;
  final Widget buttonChild;
  final VoidCallback? onPressed;
  final ValueChanged<PointerDownEvent> onPointerDown;
  final ValueChanged<PointerMoveEvent> onPointerMove;
  final ValueChanged<PointerEvent> onPointerFinish;

  @override
  Widget build(BuildContext context) {
    final active = snapPosition != _AudioRecordSnapPosition.origin;
    final icon = switch (snapPosition) {
      _AudioRecordSnapPosition.left => CupertinoIcons.delete,
      _AudioRecordSnapPosition.top => CupertinoIcons.arrow_up_circle_fill,
      _AudioRecordSnapPosition.origin => CupertinoIcons.mic_fill,
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
                  active: snapPosition == _AudioRecordSnapPosition.left,
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
                  icon: CupertinoIcons.arrow_up_circle_fill,
                  active: snapPosition == _AudioRecordSnapPosition.top,
                ),
              ),
            ),
          ),
          Listener(
            onPointerDown: onPointerDown,
            onPointerMove: onPointerMove,
            onPointerUp: onPointerFinish,
            onPointerCancel: onPointerFinish,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size(size, size),
              onPressed: onPressed,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: CupertinoColors.activeBlue.resolveFrom(context),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: CupertinoColors.activeBlue.withAlpha(80),
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
            ? CupertinoColors.activeBlue.resolveFrom(context)
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

class _VoiceDraftPanel extends StatelessWidget {
  const _VoiceDraftPanel({
    required this.draft,
    required this.snapPosition,
    required this.onDelete,
    required this.showDelete,
  });

  final ComposerAudioDraft draft;
  final _AudioRecordSnapPosition snapPosition;
  final VoidCallback? onDelete;
  final bool showDelete;

  String _formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final hint = switch (draft.phase) {
      ComposerAudioDraftPhase.requestingPermission =>
        l10n.voiceWaitingForMicrophone,
      ComposerAudioDraftPhase.recording =>
        snapPosition == _AudioRecordSnapPosition.left
            ? l10n.deleteRecording
            : snapPosition == _AudioRecordSnapPosition.top
            ? l10n.sendVoiceMessage
            : l10n.voiceReleaseToSave,
      ComposerAudioDraftPhase.recorded => l10n.voiceMessage,
      ComposerAudioDraftPhase.uploading => l10n.voiceUploadingProgress(
        (draft.progress * 100).round(),
      ),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: draft.isRecording
                  ? CupertinoColors.systemRed.withAlpha(30)
                  : colors.composerReplyPreviewSurface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              draft.isRecording
                  ? CupertinoIcons.mic_fill
                  : CupertinoIcons.doc_fill,
              size: 16,
              color: draft.isRecording
                  ? CupertinoColors.systemRed
                  : CupertinoColors.activeBlue.resolveFrom(context),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatDuration(draft.duration),
                  style: appTextStyle(
                    context,
                    fontSize: AppFontSizes.body,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appSecondaryTextStyle(
                    context,
                    fontSize: AppFontSizes.meta,
                  ),
                ),
              ],
            ),
          ),
          if (showDelete) ...[
            const SizedBox(width: 6),
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: const Size(30, 30),
              onPressed: onDelete,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: onDelete == null
                      ? CupertinoColors.systemGrey3.resolveFrom(context)
                      : CupertinoColors.systemGrey.resolveFrom(context),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  CupertinoIcons.delete_solid,
                  size: 16,
                  color: CupertinoColors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
