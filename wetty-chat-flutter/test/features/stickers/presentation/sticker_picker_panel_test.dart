import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chahua/core/api/services/sticker_api_service.dart';
import 'package:chahua/core/api/models/messages_api_models.dart';
import 'package:chahua/core/api/models/stickers_api_models.dart';
import 'package:chahua/core/providers/shared_preferences_provider.dart';
import 'package:chahua/features/stickers/presentation/sticker_picker_panel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('picker uses responsive layout on wider widths', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        stickerApiServiceProvider.overrideWithValue(
          _FakeStickerApiService(
            favorites: List.generate(5, (index) => _stickerDto('s$index')),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: CupertinoApp(
          home: CupertinoPageScaffold(
            child: SafeArea(
              child: StickerPickerPanel(onStickerSelected: (_) {}),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final firstSticker = find.byKey(const ValueKey('picker-sticker-s0'));
    final fifthSticker = find.byKey(const ValueKey('picker-sticker-s4'));

    expect(firstSticker, findsOneWidget);
    expect(fifthSticker, findsOneWidget);

    final firstSize = tester.getSize(firstSticker);
    expect(firstSize.width, closeTo(firstSize.height, 0.01));
    expect(firstSize.width, lessThanOrEqualTo(88));
    expect(
      tester.getTopLeft(fifthSticker).dy,
      closeTo(tester.getTopLeft(firstSticker).dy, 0.01),
    );
  });
}

class _FakeStickerApiService extends StickerApiService {
  _FakeStickerApiService({required this.favorites}) : super(Dio());

  final List<StickerSummaryDto> favorites;

  @override
  Future<StickerPackListResponseDto> fetchOwnedPacks() async {
    return const StickerPackListResponseDto();
  }

  @override
  Future<StickerPackListResponseDto> fetchSubscribedPacks() async {
    return const StickerPackListResponseDto();
  }

  @override
  Future<FavoriteStickerListResponseDto> fetchFavorites() async {
    return FavoriteStickerListResponseDto(stickers: favorites);
  }

  @override
  Future<void> saveStickerPackOrder(List<dynamic> order) async {}
}

StickerSummaryDto _stickerDto(String id) {
  return StickerSummaryDto(
    id: id,
    emoji: '😀',
    media: StickerMediaDto(id: 'media-$id', url: ''),
  );
}
