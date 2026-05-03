import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chahua/features/shared/presentation/adaptive_cupertino_popup.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('uses bottom sheet geometry on compact widths', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_TestApp());

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final content = find.byKey(_TestApp.contentKey);
    expect(tester.getSize(content), const Size(430, 450));
    expect(tester.getTopLeft(content), const Offset(0, 450));
  });

  testWidgets('uses centered constrained geometry on regular widths', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(900, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_TestApp());

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    final content = find.byKey(_TestApp.contentKey);
    expect(tester.getSize(content), const Size(520, 680));
    expect(tester.getTopLeft(content), const Offset(190, 110));
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp();

  static const contentKey = ValueKey('adaptive-popup-content');

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      home: CupertinoPageScaffold(
        child: Center(
          child: Builder(
            builder: (context) {
              return CupertinoButton(
                onPressed: () {
                  showAdaptiveCupertinoPopup<void>(
                    context: context,
                    builder: (_) => const SizedBox.expand(key: contentKey),
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );
  }
}
