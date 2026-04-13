import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

class StickerGridLayout {
  const StickerGridLayout({
    required this.columnCount,
    required this.tileExtent,
    required this.contentWidth,
    required this.crossAxisSpacing,
  });

  static const int defaultCompactColumnCount = 4;
  static const double defaultMaxTileExtent = 92;

  final int columnCount;
  final double tileExtent;
  final double contentWidth;
  final double crossAxisSpacing;

  static StickerGridLayout fromWidth(
    double availableWidth, {
    required double horizontalPadding,
    required double crossAxisSpacing,
    int compactColumnCount = defaultCompactColumnCount,
    double maxTileExtent = defaultMaxTileExtent,
  }) {
    final contentWidth = math.max(
      0.0,
      availableWidth - (horizontalPadding * 2),
    );
    final minColumnCount = math.max(1, compactColumnCount);
    final requiredColumnCount =
        ((contentWidth + crossAxisSpacing) / (maxTileExtent + crossAxisSpacing))
            .ceil();
    final columnCount = math.max(minColumnCount, requiredColumnCount);
    final totalSpacing = crossAxisSpacing * (columnCount - 1);
    final tileExtent = columnCount == 0
        ? 0.0
        : math.max(0.0, (contentWidth - totalSpacing) / columnCount);

    return StickerGridLayout(
      columnCount: columnCount,
      tileExtent: tileExtent,
      contentWidth: contentWidth,
      crossAxisSpacing: crossAxisSpacing,
    );
  }

  SliverGridDelegate buildDelegate({required double mainAxisSpacing}) {
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columnCount,
      mainAxisSpacing: mainAxisSpacing,
      crossAxisSpacing: crossAxisSpacing,
      childAspectRatio: 1,
    );
  }
}
