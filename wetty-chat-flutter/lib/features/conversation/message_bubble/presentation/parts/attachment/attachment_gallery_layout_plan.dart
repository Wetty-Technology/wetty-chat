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
    required this.width,
    required this.height,
    required this.topInset,
  });

  final AttachmentItem attachment;
  final double width;
  final double height;
  final double topInset;
}
