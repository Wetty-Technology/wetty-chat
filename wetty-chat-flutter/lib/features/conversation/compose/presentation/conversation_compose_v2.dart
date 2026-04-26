import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/features/conversation/compose/presentation/conversation_composer_view_model.dart';
import 'package:chahua/features/conversation/shared/domain/conversation_identity.dart';
import 'package:chahua/features/conversation/compose/presentation/conversation_v2_composer_bar.dart';
import 'package:chahua/features/shared/model/message/message.dart';
import 'package:chahua/features/stickers/presentation/sticker_picker_panel.dart';

class ConversationComposeV2 extends ConsumerStatefulWidget {
  const ConversationComposeV2({
    super.key,
    required this.identity,
    this.onMessageSent,
  });

  final ConversationIdentity identity;
  final Future<void> Function()? onMessageSent;

  @override
  ConversationComposeV2State createState() => ConversationComposeV2State();
}

class ConversationComposeV2State extends ConsumerState<ConversationComposeV2> {
  bool _isStickerPickerOpen = false;
  bool _isInputFocused = false;

  bool get hasActiveInputFocus => _isInputFocused;

  void dismissTransientUi() {
    if (!_isStickerPickerOpen) {
      return;
    }
    setState(() {
      _isStickerPickerOpen = false;
    });
  }

  void _toggleStickerPicker() {
    setState(() {
      _isStickerPickerOpen = !_isStickerPickerOpen;
      if (_isStickerPickerOpen) {
        FocusScope.of(context).unfocus();
      }
    });
  }

  void _handleInputFocusChanged(bool hasFocus) {
    if (_isInputFocused == hasFocus) {
      return;
    }
    setState(() {
      _isInputFocused = hasFocus;
    });
  }

  Future<void> _sendSticker(StickerSummary sticker) async {
    unawaited(
      ref
          .read(conversationComposerViewModelProvider(widget.identity).notifier)
          .sendSticker(sticker),
    );
    unawaited(widget.onMessageSent?.call());
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final bottomInset = _isStickerPickerOpen
        ? viewPadding.bottom
        : math.max(viewInsets.bottom, viewPadding.bottom);

    return ColoredBox(
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
              onMessageSent: widget.onMessageSent,
              onToggleStickerPicker: _toggleStickerPicker,
              onInputFocusChanged: _handleInputFocusChanged,
              isStickerPickerOpen: _isStickerPickerOpen,
            ),
            if (_isStickerPickerOpen)
              SizedBox(
                width: double.infinity,
                child: StickerPickerPanel(
                  onStickerSelected: _sendSticker,
                  onClose: dismissTransientUi,
                ),
              ),
            SizedBox(height: bottomInset),
          ],
        ),
      ),
    );
  }
}
