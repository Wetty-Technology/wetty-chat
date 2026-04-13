import 'package:flutter_test/flutter_test.dart';

import 'package:chahua/features/stickers/presentation/widgets/sticker_grid_layout.dart';

void main() {
  test('compact phone width keeps four columns', () {
    final layout = StickerGridLayout.fromWidth(
      375,
      horizontalPadding: 8,
      crossAxisSpacing: 4,
    );

    expect(layout.columnCount, 4);
    expect(layout.tileExtent, closeTo(86.75, 0.01));
  });

  test('standard phone width still stays roughly four-up', () {
    final layout = StickerGridLayout.fromWidth(
      390,
      horizontalPadding: 8,
      crossAxisSpacing: 4,
    );

    expect(layout.columnCount, 4);
    expect(layout.tileExtent, closeTo(90.5, 0.01));
  });

  test(
    'wide layout increases column count when tiles would exceed max size',
    () {
      final layout = StickerGridLayout.fromWidth(
        430,
        horizontalPadding: 8,
        crossAxisSpacing: 4,
      );

      expect(layout.columnCount, 5);
      expect(layout.tileExtent, closeTo(79.6, 0.01));
    },
  );

  test('tile widths fill the row exactly after spacing and padding math', () {
    final layout = StickerGridLayout.fromWidth(
      768,
      horizontalPadding: 8,
      crossAxisSpacing: 4,
    );

    final consumedWidth =
        (layout.tileExtent * layout.columnCount) +
        (layout.crossAxisSpacing * (layout.columnCount - 1));

    expect(consumedWidth, closeTo(layout.contentWidth, 0.0001));
  });
}
