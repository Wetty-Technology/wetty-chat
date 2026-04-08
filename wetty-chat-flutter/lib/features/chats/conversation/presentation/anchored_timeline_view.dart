import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';

import '../domain/timeline_entry.dart';
import '../domain/viewport_placement.dart';

typedef TimelineEntryBuilder =
    Widget Function(BuildContext context, TimelineEntry entry, int index);
typedef TimelineEdgeCallback = void Function();

@visibleForTesting
double resolveTopPreferredAnchorAlignment({
  required double afterExtent,
  required double viewportExtent,
}) {
  if (viewportExtent <= 0) {
    return 0;
  }
  final visibleFractionBelowAnchor = (afterExtent / viewportExtent).clamp(
    0.0,
    1.0,
  );
  return 1.0 - visibleFractionBelowAnchor;
}

/// A chat timeline view built on [CustomScrollView] with the `center` key
/// pattern to anchor a specific entry at a given viewport fraction.
///
/// Content before the anchor grows upward (older messages) and content after
/// grows downward (newer messages). Requested top placement is clamped against
/// rendered trailing extent so the anchor is never placed into empty space.
class AnchoredTimelineView extends StatefulWidget {
  const AnchoredTimelineView({
    super.key,
    required this.entries,
    required this.anchorIndex,
    required this.viewportPlacement,
    required this.entryBuilder,
    this.onNearOlderEdge,
    this.onNearNewerEdge,
    this.topPadding = 0,
    this.bottomPadding = 0,
    this.scrollController,
  });

  /// All timeline entries in chronological order (oldest first).
  final List<TimelineEntry> entries;

  /// Index into [entries] that serves as the scroll anchor.
  final int anchorIndex;

  final ConversationViewportPlacement viewportPlacement;

  final TimelineEntryBuilder entryBuilder;
  final TimelineEdgeCallback? onNearOlderEdge;
  final TimelineEdgeCallback? onNearNewerEdge;
  final double topPadding;
  final double bottomPadding;
  final ScrollController? scrollController;

  @override
  State<AnchoredTimelineView> createState() => _AnchoredTimelineViewState();
}

class _AnchoredTimelineViewState extends State<AnchoredTimelineView> {
  static const double _edgeThresholdPixels = 200;

  final _centerKey = GlobalKey();
  late ScrollController _scrollController;
  bool _ownsController = false;
  bool _isMeasureScheduled = false;
  double _topPreferredAlignment = 0;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void didUpdateWidget(AnchoredTimelineView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scrollController != oldWidget.scrollController) {
      if (_ownsController) {
        _scrollController.removeListener(_onScroll);
        _scrollController.dispose();
      } else {
        _scrollController.removeListener(_onScroll);
      }
      _initController();
    }
    if (widget.viewportPlacement != oldWidget.viewportPlacement ||
        widget.anchorIndex != oldWidget.anchorIndex ||
        widget.entries.length != oldWidget.entries.length ||
        widget.bottomPadding != oldWidget.bottomPadding) {
      _topPreferredAlignment = 0;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    if (_ownsController) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  void _initController() {
    if (widget.scrollController != null) {
      _scrollController = widget.scrollController!;
      _ownsController = false;
    } else {
      _scrollController = ScrollController();
      _ownsController = true;
    }
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;

    // Near older edge: scroll offset near minScrollExtent (negative = up).
    if (widget.onNearOlderEdge != null &&
        position.pixels - position.minScrollExtent < _edgeThresholdPixels) {
      widget.onNearOlderEdge!();
    }

    // Near newer edge: scroll offset near maxScrollExtent (positive = down).
    if (widget.onNearNewerEdge != null &&
        position.maxScrollExtent - position.pixels < _edgeThresholdPixels) {
      widget.onNearNewerEdge!();
    }
  }

  void _scheduleTopPreferredMeasurement() {
    if (_isMeasureScheduled ||
        widget.viewportPlacement !=
            ConversationViewportPlacement.topPreferred) {
      return;
    }
    _isMeasureScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isMeasureScheduled = false;
      if (!mounted ||
          widget.viewportPlacement !=
              ConversationViewportPlacement.topPreferred) {
        return;
      }
      final renderObject = _centerKey.currentContext?.findRenderObject();
      if (renderObject is! RenderSliver) {
        return;
      }
      final afterExtent = renderObject.geometry?.scrollExtent;
      final viewportExtent = _scrollController.hasClients
          ? _scrollController.position.viewportDimension
          : context.size?.height;
      if (afterExtent == null ||
          viewportExtent == null ||
          viewportExtent <= 0) {
        return;
      }
      final nextAlignment = resolveTopPreferredAnchorAlignment(
        afterExtent: afterExtent + widget.bottomPadding,
        viewportExtent: viewportExtent,
      );
      if ((nextAlignment - _topPreferredAlignment).abs() < 0.001) {
        return;
      }
      setState(() {
        _topPreferredAlignment = nextAlignment;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.entries.isEmpty) {
      return const CustomScrollView(slivers: []);
    }
    final anchorIndex = widget.anchorIndex.clamp(0, widget.entries.length - 1);
    final isBottomAnchored =
        widget.viewportPlacement == ConversationViewportPlacement.liveEdge;
    if (!isBottomAnchored) {
      _scheduleTopPreferredMeasurement();
    }
    final anchorAlignment = isBottomAnchored ? 1.0 : _topPreferredAlignment;

    // For bottom-anchored (liveEdge): ALL entries go in the before-center
    // sliver which grows upward. The center sliver is empty. This ensures
    // the last entry's bottom edge is at the viewport bottom — not its top
    // edge, which would push it out of view.
    //
    // For top-anchored (topPreferred): entries split at the anchor index.
    // Before-anchor grows upward, anchor + newer grows downward.
    final int beforeCount;
    final int afterCount;
    if (isBottomAnchored) {
      beforeCount = widget.entries.length;
      afterCount = 0;
    } else {
      beforeCount = anchorIndex;
      afterCount = widget.entries.length - anchorIndex;
    }

    // Before-center slivers are laid out in reverse order growing upward:
    // the last sliver listed before center is closest to the viewport anchor.
    //
    // For bottom-anchored (liveEdge), bottom padding goes in the before-center
    // area closest to center so it's visible at the very bottom of the list.
    // For top-anchored, bottom padding goes after center as usual.
    return CustomScrollView(
      controller: _scrollController,
      center: _centerKey,
      anchor: anchorAlignment,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        // Top padding — always before center (furthest from anchor).
        if (widget.topPadding > 0)
          SliverPadding(padding: EdgeInsets.only(bottom: widget.topPadding)),

        // Older entries — grows upward from the center.
        SliverList.builder(
          itemCount: beforeCount,
          itemBuilder: (context, index) {
            final entryIndex = beforeCount - 1 - index;
            final entry = widget.entries[entryIndex];
            return widget.entryBuilder(context, entry, entryIndex);
          },
        ),

        // Bottom padding before center (only for bottom-anchored).
        if (isBottomAnchored && widget.bottomPadding > 0)
          SliverPadding(padding: EdgeInsets.only(bottom: widget.bottomPadding)),

        // Center sliver — anchor point for the scroll view.
        SliverList.builder(
          key: _centerKey,
          itemCount: afterCount,
          itemBuilder: (context, index) {
            final entryIndex = anchorIndex + index;
            final entry = widget.entries[entryIndex];
            return widget.entryBuilder(context, entry, entryIndex);
          },
        ),

        // Bottom padding after center (only for top-anchored).
        if (!isBottomAnchored && widget.bottomPadding > 0)
          SliverPadding(padding: EdgeInsets.only(top: widget.bottomPadding)),
      ],
    );
  }
}
