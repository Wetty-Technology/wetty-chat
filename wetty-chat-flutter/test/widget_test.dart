import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';

void main() {
  testWidgets('MyApp builds a Cupertino app shell', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MyApp(
        home: CupertinoPageScaffold(child: Center(child: Text('Smoke Test'))),
      ),
    );

    expect(find.byType(CupertinoApp), findsOneWidget);
    expect(find.text('Smoke Test'), findsOneWidget);
  });
}
