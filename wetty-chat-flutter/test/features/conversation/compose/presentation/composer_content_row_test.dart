import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chahua/features/conversation/compose/presentation/composer_audio_controls.dart';
import 'package:chahua/features/conversation/compose/presentation/composer_content_row.dart';
import 'package:chahua/features/conversation/compose/presentation/conversation_composer_view_model.dart';
import 'package:chahua/l10n/app_localizations.dart';

void main() {
  testWidgets('uses newline as the compose input action', (tester) async {
    final textController = TextEditingController();
    final focusNode = FocusNode();
    final inputScrollController = ScrollController();
    addTearDown(textController.dispose);
    addTearDown(focusNode.dispose);
    addTearDown(inputScrollController.dispose);

    await tester.pumpWidget(
      CupertinoApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CupertinoPageScaffold(
          child: ComposerContentRow(
            composer: const ConversationComposerState(
              draft: '',
              mode: ComposerIdle(),
              attachments: [],
              audioDraft: null,
              savedDraftBeforeEdit: null,
              nextClientGeneratedId: 'client-1',
            ),
            textController: textController,
            focusNode: focusNode,
            inputScrollController: inputScrollController,
            snapPosition: ComposerAudioSnapPosition.origin,
            fieldMinHeight: 36,
            onDraftChanged: (_) {},
            onSend: () async {},
            onDeleteAudioDraft: () async {},
          ),
        ),
      ),
    );

    final textField = tester.widget<CupertinoTextField>(
      find.byType(CupertinoTextField),
    );
    expect(textField.textInputAction, TextInputAction.newline);
  });
}
