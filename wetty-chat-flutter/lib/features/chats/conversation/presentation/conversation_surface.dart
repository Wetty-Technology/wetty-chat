import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/style_config.dart';
import '../../../stickers/presentation/sticker_picker_panel.dart';
import '../../../stickers/presentation/sticker_preview_modal.dart';
import '../../models/message_models.dart';
import '../application/conversation_composer_view_model.dart';
import '../application/conversation_timeline_view_model.dart';
import '../domain/conversation_message.dart';
import '../domain/conversation_scope.dart';
import 'compose/conversation_composer_bar.dart';
import 'timeline/conversation_timeline.dart';

class ConversationSurface extends ConsumerStatefulWidget {
  const ConversationSurface({
    super.key,
    required this.scope,
    required this.timelineArgs,
    this.onOpenThread,
    this.onTapMention,
    this.onLatestVisibleMessageChanged,
    this.logTag = 'ConversationSurface',
  });

  final ConversationScope scope;
  final ConversationTimelineArgs timelineArgs;
  final void Function(ConversationMessage message)? onOpenThread;
  final void Function(int uid, MentionInfo? mention)? onTapMention;
  final void Function(ConversationMessage message)?
  onLatestVisibleMessageChanged;
  final String logTag;

  @override
  ConsumerState<ConversationSurface> createState() =>
      _ConversationSurfaceState();
}

class _ConversationSurfaceState extends ConsumerState<ConversationSurface> {
  final ConversationTimelineController _timelineController =
      ConversationTimelineController();

  bool _isStickerPickerOpen = false;

  Future<void> _handleMessageSent() async {
    await _timelineController.scrollToLatest();
  }

  void _toggleStickerPicker() {
    setState(() {
      _isStickerPickerOpen = !_isStickerPickerOpen;
      if (_isStickerPickerOpen) {
        FocusScope.of(context).unfocus();
      }
    });
  }

  void _handleStickerSelected(StickerSummary sticker) {
    if (sticker.id == null) {
      return;
    }
    unawaited(
      ref
          .read(conversationComposerViewModelProvider(widget.scope).notifier)
          .sendSticker(sticker),
    );
    setState(() {
      _isStickerPickerOpen = false;
    });
    unawaited(_handleMessageSent());
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        children: [
          Expanded(
            child: Container(
              color: colors.chatBackground,
              child: ConversationTimeline(
                scope: widget.scope,
                timelineArgs: widget.timelineArgs,
                controller: _timelineController,
                logTag: widget.logTag,
                onOpenThread: widget.onOpenThread,
                onTapSticker: (message) {
                  final stickerId = message.sticker?.id;
                  if (stickerId != null) {
                    showStickerPreviewModal(context, stickerId);
                  }
                },
                onTapMention: widget.onTapMention,
                onLatestVisibleMessageChanged:
                    widget.onLatestVisibleMessageChanged,
              ),
            ),
          ),
          ColoredBox(
            color: colors.backgroundSecondary,
            child: SafeArea(
              top: false,
              bottom: !_isStickerPickerOpen,
              child: ConversationComposerBar(
                scope: widget.scope,
                onMessageSent: _handleMessageSent,
                onToggleStickerPicker: _toggleStickerPicker,
                isStickerPickerOpen: _isStickerPickerOpen,
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: _isStickerPickerOpen
                ? SafeArea(
                    top: false,
                    child: StickerPickerPanel(
                      onStickerSelected: _handleStickerSelected,
                      onClose: () =>
                          setState(() => _isStickerPickerOpen = false),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
