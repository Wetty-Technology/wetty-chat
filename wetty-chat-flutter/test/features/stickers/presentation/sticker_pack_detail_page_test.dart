import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chahua/core/api/services/sticker_api_service.dart';
import 'package:chahua/core/api/models/messages_api_models.dart';
import 'package:chahua/core/api/models/stickers_api_models.dart';
import 'package:chahua/core/session/dev_session_store.dart';
import 'package:chahua/features/stickers/presentation/sticker_pack_detail_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('owner pack detail keeps add cell in the responsive grid', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        devSessionProvider.overrideWithValue(1),
        stickerApiServiceProvider.overrideWithValue(
          _FakeStickerApiService(
            stickers: List.generate(4, (index) => _stickerDto('s$index')),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const CupertinoApp(
          home: StickerPackDetailPage(packId: 'pack-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final addCell = find.byKey(const Key('add-sticker-cell'));
    final fourthSticker = find.byKey(const ValueKey('pack-sticker-s3'));

    expect(addCell, findsOneWidget);
    expect(fourthSticker, findsOneWidget);

    final addCellSize = tester.getSize(addCell);
    expect(addCellSize.width, closeTo(addCellSize.height, 0.01));
    expect(
      tester.getTopLeft(fourthSticker).dy,
      closeTo(tester.getTopLeft(addCell).dy, 0.01),
    );
  });
}

class _FakeStickerApiService extends StickerApiService {
  _FakeStickerApiService({required this.stickers}) : super(Dio());

  final List<StickerSummaryDto> stickers;

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
