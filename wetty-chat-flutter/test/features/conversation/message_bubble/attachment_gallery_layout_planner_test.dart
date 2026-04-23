import 'package:chahua/features/chats/models/message_models.dart';
import 'package:chahua/features/conversation/message_bubble/presentation/parts/attachment/attachment_gallery_layout_plan.dart';
import 'package:chahua/features/conversation/message_bubble/presentation/parts/attachment/attachment_gallery_layout_planner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildAttachmentGalleryLayoutPlan', () {
    test('returns empty plan for empty attachments', () {
      final plan = buildAttachmentGalleryLayoutPlan(
        const <AttachmentItem>[],
        maxWidth: 280,
      );

      expect(plan.width, 0);
      expect(plan.height, 0);
      expect(plan.tiles, isEmpty);
    });

    test('keeps two portrait attachments side by side', () {
      final plan = buildAttachmentGalleryLayoutPlan([
        _imageAttachment(id: '1', width: 600, height: 1400),
        _imageAttachment(id: '2', width: 620, height: 1500),
      ], maxWidth: 280);

      expect(plan.tiles, hasLength(2));
      expect(plan.tiles[0].top, 0);
      expect(plan.tiles[1].top, 0);
      expect(plan.tiles[1].left, greaterThan(plan.tiles[0].left));
      expect(plan.tiles[0].height, closeTo(plan.tiles[1].height, 0.001));
      _expectTilesInBounds(plan);
      _expectNoOverlaps(plan.tiles);
    });

    test('three attachments keep first tile dominant', () {
      final plan = buildAttachmentGalleryLayoutPlan([
        _imageAttachment(id: '1', width: 1200, height: 1100),
        _imageAttachment(id: '2', width: 800, height: 800),
        _videoAttachment(id: '3', width: 720, height: 720),
      ], maxWidth: 280);

      expect(plan.tiles, hasLength(3));
      final firstArea = _area(plan.tiles[0]);
      expect(firstArea, greaterThanOrEqualTo(_area(plan.tiles[1])));
      expect(firstArea, greaterThanOrEqualTo(_area(plan.tiles[2])));
      _expectTilesInBounds(plan);
      _expectNoOverlaps(plan.tiles);
    });

    test('caps visible tiles at six and marks overflow on last tile', () {
      final plan = buildAttachmentGalleryLayoutPlan(
        List<AttachmentItem>.generate(
          8,
          (index) => _imageAttachment(
            id: '$index',
            width: 1000 + (index * 10),
            height: 800,
          ),
        ),
        maxWidth: 280,
      );

      expect(plan.tiles, hasLength(6));
      expect(plan.tiles.last.showsOverflowOverlay, isTrue);
      expect(plan.tiles.last.overflowCount, 2);
      expect(
        plan.tiles.take(5).every((tile) => !tile.showsOverflowOverlay),
        isTrue,
      );
      _expectTilesInBounds(plan);
      _expectNoOverlaps(plan.tiles);
    });

    test('preserves source order in the output tiles', () {
      final attachments = [
        _imageAttachment(id: 'a', width: 1100, height: 800),
        _imageAttachment(id: 'b', width: 800, height: 1100),
        _videoAttachment(id: 'c', width: 900, height: 900),
        _imageAttachment(id: 'd', width: 1000, height: 700),
      ];

      final plan = buildAttachmentGalleryLayoutPlan(attachments, maxWidth: 280);

      expect(
        plan.tiles.map((tile) => tile.sourceIndex).toList(),
        orderedEquals([0, 1, 2, 3]),
      );
    });

    test('clamps extreme aspect ratios so gallery height stays bounded', () {
      final plan = buildAttachmentGalleryLayoutPlan([
        _imageAttachment(id: '1', width: 10, height: 1000),
        _imageAttachment(id: '2', width: 1000, height: 10),
        _imageAttachment(id: '3', width: 20, height: 1200),
      ], maxWidth: 280);

      expect(
        plan.height,
        lessThanOrEqualTo(280 * kAttachmentGalleryMaxHeightFactor),
      );
      _expectTilesInBounds(plan);
      _expectNoOverlaps(plan.tiles);
    });
  });
}

AttachmentItem _imageAttachment({
  required String id,
  required int width,
  required int height,
}) {
  return AttachmentItem(
    id: id,
    url: 'https://example.com/$id.jpg',
    kind: 'image/jpeg',
    size: 1024,
    fileName: '$id.jpg',
    width: width,
    height: height,
  );
}

AttachmentItem _videoAttachment({
  required String id,
  required int width,
  required int height,
}) {
  return AttachmentItem(
    id: id,
    url: 'https://example.com/$id.mp4',
    kind: 'video/mp4',
    size: 2048,
    fileName: '$id.mp4',
    width: width,
    height: height,
    durationMs: 1000,
  );
}

double _area(AttachmentGalleryTilePlan tile) => tile.width * tile.height;

void _expectTilesInBounds(AttachmentGalleryLayoutPlan plan) {
  for (final tile in plan.tiles) {
    expect(tile.left, greaterThanOrEqualTo(0));
    expect(tile.top, greaterThanOrEqualTo(0));
    expect(tile.left + tile.width, lessThanOrEqualTo(plan.width + 0.001));
    expect(tile.top + tile.height, lessThanOrEqualTo(plan.height + 0.001));
  }
}

void _expectNoOverlaps(List<AttachmentGalleryTilePlan> tiles) {
  for (var i = 0; i < tiles.length; i++) {
    for (var j = i + 1; j < tiles.length; j++) {
      expect(_overlaps(tiles[i], tiles[j]), isFalse, reason: '$i overlaps $j');
    }
  }
}

bool _overlaps(AttachmentGalleryTilePlan a, AttachmentGalleryTilePlan b) {
  return a.left < b.left + b.width &&
      a.left + a.width > b.left &&
      a.top < b.top + b.height &&
      a.top + a.height > b.top;
}
