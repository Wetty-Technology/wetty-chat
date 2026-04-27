import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chahua/core/cache/app_cached_network_image.dart';
import 'package:chahua/features/chat_list/presentation/widgets/chat_list_row.dart';
import 'package:chahua/l10n/app_localizations.dart';

void main() {
  testWidgets('renders cached avatar image when avatar URL is present', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        ChatListRow(
          chatName: 'General',
          avatarUrl: 'https://example.com/group.png',
          timestampText: 'Now',
          unreadCount: 0,
          onTap: () {},
        ),
      ),
    );

    expect(find.byType(AppCachedNetworkImage), findsOneWidget);
  });

  testWidgets('falls back to the chat initial when avatar URL is unsupported', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        ChatListRow(
          chatName: 'General',
          avatarUrl: 'https://example.com/group.svg',
          timestampText: 'Now',
          unreadCount: 0,
          onTap: () {},
        ),
      ),
    );

    expect(find.text('G'), findsOneWidget);
    expect(find.byType(AppCachedNetworkImage), findsNothing);
  });
}

Widget _buildTestApp(Widget child) {
  return ProviderScope(
    child: CupertinoApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: CupertinoPageScaffold(child: ListView(children: [child])),
    ),
  );
}
