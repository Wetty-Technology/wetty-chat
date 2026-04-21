import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/features/chats/conversation_v2/application/conversation_composer_view_model.dart';
import 'package:chahua/features/chats/conversation_v2/application/conversation_timeline_v2_view_model.dart';
import 'package:chahua/features/chats/conversation_v2/domain/conversation_identity.dart';
import 'package:chahua/features/chats/conversation_v2/domain/launch_request.dart';
import 'package:chahua/features/chats/models/message_models.dart';
import 'package:chahua/features/chats/conversation_v2/presentation/compose/conversation_v2_composer_bar.dart';
import 'package:chahua/features/chats/conversation_v2/presentation/conversation_timeline_v2.dart';
import 'package:chahua/features/stickers/presentation/sticker_picker_panel.dart';

class ConversationSurfaceV2 extends ConsumerStatefulWidget {
  const ConversationSurfaceV2({
    super.key,
    required this.identity,
    required this.launchRequest,
  });

  final ConversationIdentity identity;
  final LaunchRequest launchRequest;

  @override
  ConsumerState<ConversationSurfaceV2> createState() =>
      _ConversationSurfaceV2State();
}

class _ConversationSurfaceV2State extends ConsumerState<ConversationSurfaceV2> {
  bool _isStickerPickerOpen = false;

  Future<void> _handleMessageSent() async {
    ref
        .read(conversationTimelineV2ViewModelProvider(widget.identity).notifier)
        .followLatestTailIfNeeded();
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
    setState(() {
      _isStickerPickerOpen = false;
    });
    unawaited(_sendStickerAndReturnToLatest(sticker));
  }

  Future<void> _sendStickerAndReturnToLatest(StickerSummary sticker) async {
    try {
      await ref
          .read(conversationComposerViewModelProvider(widget.identity).notifier)
          .sendSticker(sticker);
      await _handleMessageSent();
    } catch (_) {
      // Error presentation is handled by the composer state / retry flows.
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final bottomInset = _isStickerPickerOpen
        ? viewPadding.bottom
        : math.max(viewInsets.bottom, viewPadding.bottom);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              color: colors.chatBackground,
              child: ConversationTimelineV2(
                chatId: widget.identity.chatId,
                threadRootId: widget.identity.threadRootId,
                launchRequest: widget.launchRequest,
              ),
            ),
          ),
          ColoredBox(
            color: colors.backgroundSecondary,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors.inputBorder)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConversationV2ComposerBar(
                    identity: widget.identity,
                    onMessageSent: _handleMessageSent,
                    onToggleStickerPicker: _toggleStickerPicker,
                    isStickerPickerOpen: _isStickerPickerOpen,
                  ),
                  if (_isStickerPickerOpen)
                    SizedBox(
                      width: double.infinity,
                      child: StickerPickerPanel(
                        onStickerSelected: _handleStickerSelected,
                        onClose: () =>
                            setState(() => _isStickerPickerOpen = false),
                      ),
                    ),
                  SizedBox(height: bottomInset),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
