import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chahua/core/cache/app_cached_network_image.dart';
import 'package:chahua/core/cache/image_cache_service.dart';
import 'package:chahua/features/shared/presentation/avatar/app_avatar.dart';

import '../../test_utils/path_provider_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(setUpPathProviderMock);
  tearDownAll(tearDownPathProviderMock);

  testWidgets('renders fallback initial when image URL is empty', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(const AppAvatar(name: 'Alice', size: 40)),
    );

    expect(find.text('A'), findsOneWidget);
    expect(find.byType(AppCachedNetworkImage), findsNothing);
  });

  testWidgets('renders fallback for unsupported svg URLs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        const AppAvatar(
          name: 'Alice',
          imageUrl: 'https://example.com/avatar.svg?size=96',
          size: 40,
        ),
      ),
    );

    expect(find.text('A'), findsOneWidget);
    expect(find.byType(AppCachedNetworkImage), findsNothing);
  });

  testWidgets('renders cached network image for supported raster URLs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        const AppAvatar(
          name: 'Alice',
          imageUrl: 'https://example.com/avatar.png',
          size: 40,
        ),
      ),
    );

    expect(find.byType(AppCachedNetworkImage), findsOneWidget);
  });

  testWidgets('falls back to initial when image URL is malformed', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        const AppAvatar(name: 'Alice', imageUrl: 'ht@tp://bad-url', size: 40),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('uses question mark when name is empty', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(const AppAvatar(name: '   ', size: 40)),
    );

    expect(find.text('?'), findsOneWidget);
  });

  testWidgets('uses first grapheme cluster for fallback label', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(const AppAvatar(name: '👨‍👩‍👧‍👦 Family', size: 40)),
    );

    expect(find.text('👨‍👩‍👧‍👦'), findsOneWidget);
  });
}

Widget _buildTestApp(Widget child, {ImageCacheService? imageCacheService}) {
  return ProviderScope(
    overrides: [
      if (imageCacheService != null)
        imageCacheServiceProvider.overrideWithValue(imageCacheService),
    ],
    child: CupertinoApp(
      home: CupertinoPageScaffold(child: Center(child: child)),
    ),
  );
}
