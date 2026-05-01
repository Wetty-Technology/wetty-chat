import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:chahua/core/api/services/sticker_api_service.dart';
import 'package:chahua/core/api/models/messages_api_models.dart';
import 'package:chahua/core/api/models/stickers_api_models.dart';
import 'package:chahua/core/session/dev_session_store.dart';
import 'package:chahua/features/stickers/presentation/sticker_pack_detail_page.dart';
import 'package:chahua/features/stickers/presentation/sticker_preview_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'preview modal uses responsive grid and updates selection state',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final stickers = List.generate(5, (index) => _stickerDto('s$index'));
      final container = ProviderContainer(
        overrides: [
          devSessionProvider.overrideWithValue(1),
          stickerApiServiceProvider.overrideWithValue(
            _FakeStickerApiService(stickers: stickers),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: CupertinoApp(
            home: CupertinoPageScaffold(
              child: Center(
                child: CupertinoButton(
                  onPressed: () => showStickerPreviewModal(
                    tester.element(find.byType(CupertinoButton)),
                    's0',
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final firstSticker = find.byKey(const ValueKey('preview-sticker-s0'));
      final fifthSticker = find.byKey(const ValueKey('preview-sticker-s4'));

      expect(firstSticker, findsOneWidget);
      expect(fifthSticker, findsOneWidget);
      expect(
        tester.getTopLeft(fifthSticker).dy,
        closeTo(tester.getTopLeft(firstSticker).dy, 0.01),
      );

      final selectedBeforeTap =
          tester.widget<Container>(firstSticker).decoration! as BoxDecoration;
      expect(selectedBeforeTap.border, isNotNull);

      await tester.tap(find.byKey(const ValueKey('preview-sticker-s2')));
      await tester.pumpAndSettle();

      final selectedAfterTap =
          tester
                  .widget<Container>(
                    find.byKey(const ValueKey('preview-sticker-s2')),
                  )
                  .decoration!
              as BoxDecoration;
      expect(selectedAfterTap.border, isNotNull);
    },
  );

  testWidgets('manage closes the modal and navigates to pack detail', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        devSessionProvider.overrideWithValue(1),
        stickerApiServiceProvider.overrideWithValue(
          _FakeStickerApiService(stickers: [_stickerDto('s0')]),
        ),
      ],
    );
    addTearDown(container.dispose);

    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => CupertinoPageScaffold(
            child: Center(
              child: CupertinoButton(
                onPressed: () => showStickerPreviewModal(context, 's0'),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/sticker-packs/:packId',
          builder: (context, state) =>
              StickerPackDetailPage(packId: state.pathParameters['packId']!),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: CupertinoApp.router(routerConfig: router),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Manage'));
    await tester.pumpAndSettle();

    expect(find.byType(StickerPackDetailPage), findsOneWidget);
    expect(find.text('Manage'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _FakeStickerApiService extends StickerApiService {
  _FakeStickerApiService({required this.stickers}) : super(Dio());

  final List<StickerSummaryDto> stickers;

  @override
  Future<StickerDetailResponseDto> fetchStickerDetail(String stickerId) async {
    return StickerDetailResponseDto(
      id: stickerId,
      emoji: '😀',
      media: StickerMediaDto(id: 'media-$stickerId', url: ''),
      packs: [
        const StickerPackSummaryDto(id: 'pack-1', ownerUid: 1, name: 'Pack'),
      ],
    );
  }

  @override
  Future<StickerPackDetailResponseDto> fetchPackDetail(String packId) async {
    return StickerPackDetailResponseDto(
      id: packId,
      ownerUid: 1,
      name: 'Pack',
      stickers: stickers,
    );
  }
}

StickerSummaryDto _stickerDto(String id) {
  return StickerSummaryDto(
    id: id,
    emoji: '😀',
    media: StickerMediaDto(id: 'media-$id', url: ''),
  );
}
