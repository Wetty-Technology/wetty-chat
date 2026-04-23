import 'package:chahua/features/chats/models/message_models.dart';
import 'package:flutter/foundation.dart';

@immutable
class AttachmentGalleryLayoutPlan {
  const AttachmentGalleryLayoutPlan({
    required this.width,
    required this.height,
    required this.tiles,
  });

  final double width;
  final double height;
  final List<AttachmentGalleryTilePlan> tiles;
}

@immutable
class AttachmentGalleryTilePlan {
  const AttachmentGalleryTilePlan({
    required this.attachment,
    required this.sourceIndex,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    this.showsOverflowOverlay = false,
    this.overflowCount = 0,
  });

  final AttachmentItem attachment;
  final int sourceIndex;
  final double left;
  final double top;
  final double width;
  final double height;
  final bool showsOverflowOverlay;
  final int overflowCount;
}
