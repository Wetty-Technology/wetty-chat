import 'dart:math' as math;

import 'package:chahua/features/shared/model/message/message.dart';

import 'attachment_gallery_layout_plan.dart';

const double kAttachmentGallerySpacing = 2;
const double kAttachmentGalleryMinTileSize = 72;
const int kAttachmentGalleryMaxVisibleCount = 6;
const double kAttachmentGalleryMinDisplayRatio = 0.67;
const double kAttachmentGalleryMaxDisplayRatio = 1.7;
const double kAttachmentGalleryMaxHeightFactor = 1.35;

AttachmentGalleryLayoutPlan buildAttachmentGalleryLayoutPlan(
  List<AttachmentItem> attachments, {
  required double maxWidth,
  double spacing = kAttachmentGallerySpacing,
  double minTileSize = kAttachmentGalleryMinTileSize,
  int maxVisibleCount = kAttachmentGalleryMaxVisibleCount,
}) {
  if (attachments.isEmpty || maxWidth <= 0) {
    return const AttachmentGalleryLayoutPlan(
      width: 0,
      height: 0,
      tiles: <AttachmentGalleryTilePlan>[],
    );
  }

  final visibleCount = math.min(attachments.length, maxVisibleCount);
  final visibleEntries = List.generate(
    visibleCount,
    (index) => (
      attachment: attachments[index],
      sourceIndex: index,
      ratio: _normalizedDisplayRatio(attachments[index]),
    ),
    growable: false,
  );
  final overflowCount = attachments.length - visibleCount;

  final basePlan = switch (visibleCount) {
    1 => _planSingle(visibleEntries, maxWidth: maxWidth),
    2 => _planTwo(visibleEntries, maxWidth: maxWidth, spacing: spacing),
    3 => _bestPlan(
      [
        _planThreePrimaryLeft(
          visibleEntries,
          maxWidth: maxWidth,
          spacing: spacing,
          minTileSize: minTileSize,
        ),
        _planThreePrimaryTop(
          visibleEntries,
          maxWidth: maxWidth,
          spacing: spacing,
          minTileSize: minTileSize,
        ),
      ],
      ratios: visibleEntries
          .map((entry) => entry.ratio)
          .toList(growable: false),
      maxWidth: maxWidth,
      spacing: spacing,
      preserveFirstDominant: true,
    ),
    4 => _bestPlan(
      [
        _planFourGrid(visibleEntries, maxWidth: maxWidth, spacing: spacing),
        _planFourPrimaryLeft(
          visibleEntries,
          maxWidth: maxWidth,
          spacing: spacing,
          minTileSize: minTileSize,
        ),
        _planFourPrimaryTop(
          visibleEntries,
          maxWidth: maxWidth,
          spacing: spacing,
          minTileSize: minTileSize,
        ),
      ],
      ratios: visibleEntries
          .map((entry) => entry.ratio)
          .toList(growable: false),
      maxWidth: maxWidth,
      spacing: spacing,
      preserveFirstDominant: true,
    ),
    5 => _planFivePrimaryLeft(
      visibleEntries,
      maxWidth: maxWidth,
      spacing: spacing,
      minTileSize: minTileSize,
    ),
    _ => _planSixGrid(
      visibleEntries,
      maxWidth: maxWidth,
      spacing: spacing,
      minTileSize: minTileSize,
    ),
  };

  return _withOverflow(basePlan, overflowCount);
}

double _normalizedDisplayRatio(AttachmentItem attachment) {
  final width = attachment.width?.toDouble();
  final height = attachment.height?.toDouble();
  if (width == null || height == null || width <= 0 || height <= 0) {
    return 1.0;
  }
  return (width / height).clamp(
    kAttachmentGalleryMinDisplayRatio,
    kAttachmentGalleryMaxDisplayRatio,
  );
}

AttachmentGalleryLayoutPlan _withOverflow(
  AttachmentGalleryLayoutPlan plan,
  int overflowCount,
) {
  if (overflowCount <= 0 || plan.tiles.isEmpty) {
    return plan;
  }

  final tiles = <AttachmentGalleryTilePlan>[
    for (var index = 0; index < plan.tiles.length; index++)
      if (index == plan.tiles.length - 1)
        AttachmentGalleryTilePlan(
          attachment: plan.tiles[index].attachment,
          sourceIndex: plan.tiles[index].sourceIndex,
          left: plan.tiles[index].left,
          top: plan.tiles[index].top,
          width: plan.tiles[index].width,
          height: plan.tiles[index].height,
          showsOverflowOverlay: true,
          overflowCount: overflowCount,
        )
      else
        plan.tiles[index],
  ];
  return AttachmentGalleryLayoutPlan(
    width: plan.width,
    height: plan.height,
    tiles: tiles,
  );
}

AttachmentGalleryLayoutPlan _planSingle(
  List<({AttachmentItem attachment, int sourceIndex, double ratio})> entries, {
  required double maxWidth,
}) {
  final ratio = entries.first.ratio;
  final height = (maxWidth / ratio).clamp(120.0, maxWidth * 1.1).toDouble();
  return AttachmentGalleryLayoutPlan(
    width: maxWidth,
    height: height,
    tiles: [
      AttachmentGalleryTilePlan(
        attachment: entries.first.attachment,
        sourceIndex: entries.first.sourceIndex,
        left: 0,
        top: 0,
        width: maxWidth,
        height: height,
      ),
    ],
  );
}

AttachmentGalleryLayoutPlan _planTwo(
  List<({AttachmentItem attachment, int sourceIndex, double ratio})> entries, {
  required double maxWidth,
  required double spacing,
}) {
  final tileWidth = (maxWidth - spacing) / 2;
  final averageRatio =
      entries.map((entry) => entry.ratio).reduce((a, b) => a + b) /
      entries.length;
  final height = (tileWidth / averageRatio)
      .clamp(110.0, maxWidth * 0.95)
      .toDouble();
  return AttachmentGalleryLayoutPlan(
    width: maxWidth,
    height: height,
    tiles: [
      for (var index = 0; index < entries.length; index++)
        AttachmentGalleryTilePlan(
          attachment: entries[index].attachment,
          sourceIndex: entries[index].sourceIndex,
          left: index * (tileWidth + spacing),
          top: 0,
          width: tileWidth,
          height: height,
        ),
    ],
  );
}

AttachmentGalleryLayoutPlan _planThreePrimaryLeft(
  List<({AttachmentItem attachment, int sourceIndex, double ratio})> entries, {
  required double maxWidth,
  required double spacing,
  required double minTileSize,
}) {
  final leftWidth = math.max(minTileSize, (maxWidth - spacing) * 0.58);
  final rightWidth = maxWidth - spacing - leftWidth;
  final totalHeight = (leftWidth / entries.first.ratio)
      .clamp(150.0, maxWidth * 1.05)
      .toDouble();
  final rightHeights = _splitStackHeights(
    totalExtent: totalHeight,
    ratios: [entries[1].ratio, entries[2].ratio],
    spacing: spacing,
    minTileSize: minTileSize,
  );

  return AttachmentGalleryLayoutPlan(
    width: maxWidth,
    height: totalHeight,
    tiles: [
      AttachmentGalleryTilePlan(
        attachment: entries[0].attachment,
        sourceIndex: entries[0].sourceIndex,
        left: 0,
        top: 0,
        width: leftWidth,
        height: totalHeight,
      ),
      AttachmentGalleryTilePlan(
        attachment: entries[1].attachment,
        sourceIndex: entries[1].sourceIndex,
        left: leftWidth + spacing,
        top: 0,
        width: rightWidth,
        height: rightHeights.first,
      ),
      AttachmentGalleryTilePlan(
        attachment: entries[2].attachment,
        sourceIndex: entries[2].sourceIndex,
        left: leftWidth + spacing,
        top: rightHeights.first + spacing,
        width: rightWidth,
        height: rightHeights.last,
      ),
    ],
  );
}

AttachmentGalleryLayoutPlan _planThreePrimaryTop(
  List<({AttachmentItem attachment, int sourceIndex, double ratio})> entries, {
  required double maxWidth,
  required double spacing,
  required double minTileSize,
}) {
  final topHeight = (maxWidth / entries.first.ratio)
      .clamp(120.0, maxWidth * 0.72)
      .toDouble();
  final bottomWidth = (maxWidth - spacing) / 2;
  final bottomHeight =
      (bottomWidth / ((entries[1].ratio + entries[2].ratio) / 2))
          .clamp(minTileSize, maxWidth * 0.8)
          .toDouble();
  final totalHeight = topHeight + spacing + bottomHeight;

  return AttachmentGalleryLayoutPlan(
    width: maxWidth,
    height: totalHeight,
    tiles: [
      AttachmentGalleryTilePlan(
        attachment: entries[0].attachment,
        sourceIndex: entries[0].sourceIndex,
        left: 0,
        top: 0,
        width: maxWidth,
        height: topHeight,
      ),
      AttachmentGalleryTilePlan(
        attachment: entries[1].attachment,
        sourceIndex: entries[1].sourceIndex,
        left: 0,
        top: topHeight + spacing,
        width: bottomWidth,
        height: bottomHeight,
      ),
      AttachmentGalleryTilePlan(
        attachment: entries[2].attachment,
        sourceIndex: entries[2].sourceIndex,
        left: bottomWidth + spacing,
        top: topHeight + spacing,
        width: bottomWidth,
        height: bottomHeight,
      ),
    ],
  );
}

AttachmentGalleryLayoutPlan _planFourGrid(
  List<({AttachmentItem attachment, int sourceIndex, double ratio})> entries, {
  required double maxWidth,
  required double spacing,
}) {
  final tileWidth = (maxWidth - spacing) / 2;
  final topAverageRatio = (entries[0].ratio + entries[1].ratio) / 2;
  final bottomAverageRatio = (entries[2].ratio + entries[3].ratio) / 2;
  final topHeight = (tileWidth / topAverageRatio)
      .clamp(96.0, maxWidth * 0.6)
      .toDouble();
  final bottomHeight = (tileWidth / bottomAverageRatio)
      .clamp(96.0, maxWidth * 0.6)
      .toDouble();

  return AttachmentGalleryLayoutPlan(
    width: maxWidth,
    height: topHeight + spacing + bottomHeight,
    tiles: [
      for (var index = 0; index < entries.length; index++)
        AttachmentGalleryTilePlan(
          attachment: entries[index].attachment,
          sourceIndex: entries[index].sourceIndex,
          left: index.isEven ? 0 : tileWidth + spacing,
          top: index < 2 ? 0 : topHeight + spacing,
          width: tileWidth,
          height: index < 2 ? topHeight : bottomHeight,
        ),
    ],
  );
}

AttachmentGalleryLayoutPlan _planFourPrimaryLeft(
  List<({AttachmentItem attachment, int sourceIndex, double ratio})> entries, {
  required double maxWidth,
  required double spacing,
  required double minTileSize,
}) {
  final leftWidth = math.max(minTileSize, (maxWidth - spacing) * 0.54);
  final rightWidth = maxWidth - spacing - leftWidth;
  final totalHeight = (leftWidth / entries.first.ratio)
      .clamp(160.0, maxWidth * 1.15)
      .toDouble();
  final stackedHeights = _splitStackHeights(
    totalExtent: totalHeight,
    ratios: [entries[1].ratio, entries[2].ratio, entries[3].ratio],
    spacing: spacing,
    minTileSize: minTileSize,
  );

  var currentTop = 0.0;
  final tiles = <AttachmentGalleryTilePlan>[
    AttachmentGalleryTilePlan(
      attachment: entries[0].attachment,
      sourceIndex: entries[0].sourceIndex,
      left: 0,
      top: 0,
      width: leftWidth,
      height: totalHeight,
    ),
  ];
  for (var index = 1; index < entries.length; index++) {
    tiles.add(
      AttachmentGalleryTilePlan(
        attachment: entries[index].attachment,
        sourceIndex: entries[index].sourceIndex,
        left: leftWidth + spacing,
        top: currentTop,
        width: rightWidth,
        height: stackedHeights[index - 1],
      ),
    );
    currentTop += stackedHeights[index - 1];
    if (index < entries.length - 1) {
      currentTop += spacing;
    }
  }

  return AttachmentGalleryLayoutPlan(
    width: maxWidth,
    height: totalHeight,
    tiles: tiles,
  );
}

AttachmentGalleryLayoutPlan _planFourPrimaryTop(
  List<({AttachmentItem attachment, int sourceIndex, double ratio})> entries, {
  required double maxWidth,
  required double spacing,
  required double minTileSize,
}) {
  final topHeight = (maxWidth / entries.first.ratio)
      .clamp(120.0, maxWidth * 0.68)
      .toDouble();
  final bottomWidth = (maxWidth - (spacing * 2)) / 3;
  final bottomHeight =
      (bottomWidth /
              ((entries[1].ratio + entries[2].ratio + entries[3].ratio) / 3))
          .clamp(minTileSize, maxWidth * 0.6)
          .toDouble();

  return AttachmentGalleryLayoutPlan(
    width: maxWidth,
    height: topHeight + spacing + bottomHeight,
    tiles: [
      AttachmentGalleryTilePlan(
        attachment: entries[0].attachment,
        sourceIndex: entries[0].sourceIndex,
        left: 0,
        top: 0,
        width: maxWidth,
        height: topHeight,
      ),
      for (var index = 1; index < entries.length; index++)
        AttachmentGalleryTilePlan(
          attachment: entries[index].attachment,
          sourceIndex: entries[index].sourceIndex,
          left: (index - 1) * (bottomWidth + spacing),
          top: topHeight + spacing,
          width: bottomWidth,
          height: bottomHeight,
        ),
    ],
  );
}

AttachmentGalleryLayoutPlan _planFivePrimaryLeft(
  List<({AttachmentItem attachment, int sourceIndex, double ratio})> entries, {
  required double maxWidth,
  required double spacing,
  required double minTileSize,
}) {
  final leftWidth = math.max(minTileSize, (maxWidth - spacing) * 0.5);
  final rightColumnWidth = (maxWidth - leftWidth - (spacing * 2)) / 2;
  final rowHeight =
      (rightColumnWidth /
              ((entries[1].ratio +
                      entries[2].ratio +
                      entries[3].ratio +
                      entries[4].ratio) /
                  4))
          .clamp(minTileSize, maxWidth * 0.42)
          .toDouble();
  final totalHeight = (rowHeight * 2) + spacing;

  return AttachmentGalleryLayoutPlan(
    width: maxWidth,
    height: totalHeight,
    tiles: [
      AttachmentGalleryTilePlan(
        attachment: entries[0].attachment,
        sourceIndex: entries[0].sourceIndex,
        left: 0,
        top: 0,
        width: leftWidth,
        height: totalHeight,
      ),
      for (var index = 1; index < entries.length; index++)
        AttachmentGalleryTilePlan(
          attachment: entries[index].attachment,
          sourceIndex: entries[index].sourceIndex,
          left:
              leftWidth +
              spacing +
              (((index - 1) % 2) * (rightColumnWidth + spacing)),
          top: ((index - 1) ~/ 2) * (rowHeight + spacing),
          width: rightColumnWidth,
          height: rowHeight,
        ),
    ],
  );
}

AttachmentGalleryLayoutPlan _planSixGrid(
  List<({AttachmentItem attachment, int sourceIndex, double ratio})> entries, {
  required double maxWidth,
  required double spacing,
  required double minTileSize,
}) {
  final columnWidth = (maxWidth - spacing) / 2;
  final averageRatio =
      entries.map((entry) => entry.ratio).reduce((a, b) => a + b) /
      entries.length;
  final rowHeight = (columnWidth / averageRatio)
      .clamp(minTileSize, maxWidth * 0.42)
      .toDouble();

  return AttachmentGalleryLayoutPlan(
    width: maxWidth,
    height: (rowHeight * 3) + (spacing * 2),
    tiles: [
      for (var index = 0; index < entries.length; index++)
        AttachmentGalleryTilePlan(
          attachment: entries[index].attachment,
          sourceIndex: entries[index].sourceIndex,
          left: index.isEven ? 0 : columnWidth + spacing,
          top: (index ~/ 2) * (rowHeight + spacing),
          width: columnWidth,
          height: rowHeight,
        ),
    ],
  );
}

List<double> _splitStackHeights({
  required double totalExtent,
  required List<double> ratios,
  required double spacing,
  required double minTileSize,
}) {
  final available = totalExtent - (spacing * (ratios.length - 1));
  final portraitWeights = ratios
      .map((ratio) => 1 / ratio)
      .toList(growable: false);
  final totalWeight = portraitWeights.reduce((a, b) => a + b);
  final heights = <double>[];
  var used = 0.0;
  for (var index = 0; index < ratios.length; index++) {
    final height = index == ratios.length - 1
        ? available - used
        : (available * (portraitWeights[index] / totalWeight))
              .clamp(minTileSize, available)
              .toDouble();
    heights.add(height);
    used += height;
  }
  return heights;
}

AttachmentGalleryLayoutPlan _bestPlan(
  List<AttachmentGalleryLayoutPlan> candidates, {
  required List<double> ratios,
  required double maxWidth,
  required double spacing,
  required bool preserveFirstDominant,
}) {
  AttachmentGalleryLayoutPlan? bestPlan;
  double? bestScore;

  for (final candidate in candidates) {
    final score = _scorePlan(
      candidate,
      ratios: ratios,
      maxWidth: maxWidth,
      spacing: spacing,
      preserveFirstDominant: preserveFirstDominant,
    );
    if (bestScore == null || score > bestScore) {
      bestScore = score;
      bestPlan = candidate;
    }
  }

  return bestPlan!;
}

double _scorePlan(
  AttachmentGalleryLayoutPlan plan, {
  required List<double> ratios,
  required double maxWidth,
  required double spacing,
  required bool preserveFirstDominant,
}) {
  var ratioFitScore = 0.0;
  var tinyTilePenalty = 0.0;
  for (var index = 0; index < plan.tiles.length; index++) {
    final tile = plan.tiles[index];
    final tileRatio = tile.width / tile.height;
    ratioFitScore -= (tileRatio - ratios[index]).abs();
    if (tile.width < kAttachmentGalleryMinTileSize ||
        tile.height < kAttachmentGalleryMinTileSize) {
      tinyTilePenalty += 4;
    }
  }

  final heightPenalty =
      plan.height / math.max(maxWidth * kAttachmentGalleryMaxHeightFactor, 1);
  final orderPenalty = _orderPenalty(plan);
  final dominantPenalty = preserveFirstDominant && !_firstTileIsDominant(plan)
      ? 3.5
      : 0.0;

  return ratioFitScore -
      tinyTilePenalty -
      heightPenalty -
      orderPenalty -
      dominantPenalty;
}

double _orderPenalty(AttachmentGalleryLayoutPlan plan) {
  var penalty = 0.0;
  for (var index = 1; index < plan.tiles.length; index++) {
    final previous = plan.tiles[index - 1];
    final current = plan.tiles[index];
    if (current.top + 0.5 < previous.top) {
      penalty += 1.5;
    }
    if ((current.top - previous.top).abs() <= 0.5 &&
        current.left + 0.5 < previous.left) {
      penalty += 1.0;
    }
  }
  return penalty;
}

bool _firstTileIsDominant(AttachmentGalleryLayoutPlan plan) {
  if (plan.tiles.isEmpty) {
    return true;
  }
  final firstArea = plan.tiles.first.width * plan.tiles.first.height;
  for (var index = 1; index < plan.tiles.length; index++) {
    final area = plan.tiles[index].width * plan.tiles[index].height;
    if (area > firstArea + 1) {
      return false;
    }
  }
  return true;
}
