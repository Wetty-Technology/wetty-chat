import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chahua/features/conversation/message_bubble/domain/bubble_theme_v2.dart';
import 'package:chahua/features/conversation/message_bubble/presentation/sticker_bubble_v2.dart';
import 'package:chahua/features/shared/model/message/message.dart';

void main() {
  testWidgets('tapping sticker media emits the sticker id', (tester) async {
    String? openedStickerId;

    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: BubbleThemeV2(
            isMe: false,
            isInteractive: true,
            maxBubbleWidth: 240,
            timeSpacerWidth: 0,
            chatMessageFontSize: 16,
            bubbleColor: CupertinoColors.systemGrey5,
            textColor: CupertinoColors.label,
            metaColor: CupertinoColors.secondaryLabel,
            linkColor: CupertinoColors.activeBlue,
            child: StickerBubbleV2(
              message: _stickerMessage(),
              onOpenSticker: (stickerId) {
                openedStickerId = stickerId;
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('🙂'));

    expect(openedStickerId, 'sticker-1');
  });
}

ConversationMessageV2 _stickerMessage() {
  return const ConversationMessageV2(
    clientGeneratedId: 'client-1',
    sender: User(uid: 2, name: 'Sender'),
    content: StickerMessageContent(
      sticker: StickerSummary(id: 'sticker-1', emoji: '🙂'),
    ),
  );
}
