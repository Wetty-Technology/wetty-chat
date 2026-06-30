import 'dart:async';

import 'package:chahua/features/chat_list/model/chat_list_item.dart';
import 'package:chahua/features/conversation/forwarding/presentation/forward_destination_picker.dart';
import 'package:chahua/l10n/app_localizations.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('current chat can be selected as a forward destination', (
    tester,
  ) async {
    int? forwardedChatId;

    await tester.pumpWidget(
      CupertinoApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CupertinoPageScaffold(
          child: ForwardDestinationPickerContent(
            sourceChatId: 1,
            groups: const [
              ChatListItem(id: '1', name: 'Current group'),
              ChatListItem(id: '2', name: 'Project group'),
            ],
            onForward: (chatId) async {
              forwardedChatId = chatId;
              throw Exception('keep picker open');
            },
          ),
        ),
      ),
    );

    expect(find.text('Current chat'), findsOneWidget);

    await tester.tap(find.text('Current group'));
    await tester.pump();
    await tester.tap(find.widgetWithText(CupertinoButton, 'Forward').last);
    await tester.pump();

    expect(forwardedChatId, 1);
  });

  testWidgets('failure keeps picker open and enables retry', (tester) async {
    var attempts = 0;

    await tester.pumpWidget(
      CupertinoApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CupertinoPageScaffold(
          child: ForwardDestinationPickerContent(
            sourceChatId: 1,
            groups: const [ChatListItem(id: '2', name: 'Project group')],
            onForward: (chatId) async {
              attempts += 1;
              throw Exception('network failed');
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Project group'));
    await tester.pump();
    await tester.tap(find.widgetWithText(CupertinoButton, 'Forward').last);
    await tester.pump();

    expect(attempts, 1);
    expect(find.text('Error'), findsOneWidget);
    expect(find.text('Failed to send'), findsOneWidget);
    expect(find.widgetWithText(CupertinoButton, 'Retry'), findsOneWidget);

    await tester.tap(find.widgetWithText(CupertinoButton, 'Retry'));
    await tester.pump();

    expect(attempts, 2);
  });

  testWidgets('forward button shows loading and prevents duplicate submits', (
    tester,
  ) async {
    final completer = Completer<void>();
    var attempts = 0;

    await tester.pumpWidget(
      CupertinoApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CupertinoPageScaffold(
          child: ForwardDestinationPickerContent(
            sourceChatId: 1,
            groups: const [ChatListItem(id: '2', name: 'Project group')],
            onForward: (chatId) {
              attempts += 1;
              return completer.future;
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Project group'));
    await tester.pump();
    await tester.tap(find.widgetWithText(CupertinoButton, 'Forward').last);
    await tester.pump();
    final loadingButton = find.ancestor(
      of: find.byType(CupertinoActivityIndicator),
      matching: find.byType(CupertinoButton),
    );
    await tester.tap(loadingButton);
    await tester.pump();

    expect(attempts, 1);
    expect(find.byType(CupertinoActivityIndicator), findsOneWidget);

    completer.completeError(Exception('network failed'));
    await tester.pump();
  });
}
