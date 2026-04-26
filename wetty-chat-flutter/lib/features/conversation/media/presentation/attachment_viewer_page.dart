import 'dart:async';
import 'dart:math' as math;

import 'package:extended_image/extended_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chahua/l10n/app_localizations.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/cache/app_cached_network_image.dart';
import '../../../../core/cache/image_cache_service.dart';
import '../../../../core/network/api_config.dart';
import 'package:chahua/features/shared/model/message/message.dart';
import '../application/media_save_service.dart';
import 'attachment_viewer_request.dart';
import 'package:chahua/features/conversation/message_bubble/presentation/parts/attachment/video_attachment_thumbnail.dart';

class AttachmentViewerPage extends ConsumerStatefulWidget {
  const AttachmentViewerPage({super.key, required this.request});

  final AttachmentViewerRequest request;

  @override
  ConsumerState<AttachmentViewerPage> createState() =>
      _AttachmentViewerPageState();
}

class _AttachmentViewerPageState extends ConsumerState<AttachmentViewerPage> {
  static const double _thumbnailExtent = 56;
  static const double _thumbnailSpacing = 8;
  static const double _thumbnailRailHeight = 92;
  static const double _thumbnailRailHorizontalPadding = 8;
  static const double _dismissBaseScaleTolerance = 0.02;
  static const double _dismissDistanceFraction = 0.18;
  static const double _dismissMinVelocity = 900;
  static const double _dismissDirectionBias = 1.2;

  late final ExtendedPageController _pageController;
  late final ScrollController _thumbnailScrollController;
  late final List<GlobalKey<ExtendedImageGestureState>?> _gestureKeys;
  late final List<bool> _isItemAtBaseScale;
  Timer? _statusTimer;

  var _currentIndex = 0;
  var _isSlidingPage = false;
  var _isChromeVisible = true;
  var _isSaving = false;
  String? _statusMessage;
  var _statusIsError = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.request.initialIndex;
    _pageController = ExtendedPageController(initialPage: _currentIndex);
    _pageController.addListener(_handlePageScroll);
    _thumbnailScrollController = ScrollController();
    _gestureKeys = widget.request.items
        .map(
          (item) =>
              item.isImage ? GlobalKey<ExtendedImageGestureState>() : null,
        )
        .toList(growable: false);
    _isItemAtBaseScale = List<bool>.filled(
      widget.request.items.length,
      true,
      growable: false,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _precacheAdjacentImages(_currentIndex);
      _syncThumbnailRailToPage(_currentIndex.toDouble());
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _pageController.removeListener(_handlePageScroll);
    _pageController.dispose();
    _thumbnailScrollController.dispose();
    super.dispose();
  }

  bool get _hasMultipleItems => widget.request.items.length > 1;

  AttachmentViewerItem get _currentItem => widget.request.items[_currentIndex];

  bool get _isCurrentItemAtBaseScale => _isItemAtBaseScale[_currentIndex];

  bool get _canScrollCurrentPage => _isCurrentItemAtBaseScale;

  void _toggleChrome() {
    setState(() {
      _isChromeVisible = !_isChromeVisible;
    });
  }

  Future<void> _selectIndex(int index) async {
    if (index == _currentIndex) {
      return;
    }
    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _jumpToPagePosition(double page) {
    if (!_pageController.hasClients) {
      return;
    }
    final position = _pageController.position;
    final targetPixels = (page * position.viewportDimension)
        .clamp(
          position.minScrollExtent,
          math.max(position.maxScrollExtent, 0).toDouble(),
        )
        .toDouble();
    position.jumpTo(targetPixels);
  }

  void _handlePageChanged(int index) {
    if (_currentIndex == index) {
      return;
    }
    setState(() {
      _currentIndex = index;
    });
    _precacheAdjacentImages(index);
    _syncThumbnailRailToPage(index.toDouble(), animate: true);
  }

  void _handlePageScroll() {
    if (!_pageController.hasClients) {
      return;
    }
    final page = _pageController.page ?? _currentIndex.toDouble();
    _syncThumbnailRailToPage(page);
  }

  void _handleGestureDetailsChanged(int index, GestureDetails? details) {
    final totalScale = details?.totalScale ?? 1.0;
    final isAtBaseScale =
        (totalScale - 1.0).abs() <= _dismissBaseScaleTolerance;
    if (_isItemAtBaseScale[index] == isAtBaseScale) {
      return;
    }
    setState(() {
      _isItemAtBaseScale[index] = isAtBaseScale;
    });
  }

  void _handleVideoBaseScaleChanged(int index, bool isAtBaseScale) {
    if (_isItemAtBaseScale[index] == isAtBaseScale) {
      return;
    }
    setState(() {
      _isItemAtBaseScale[index] = isAtBaseScale;
    });
  }

  void _handleDoubleTap(ExtendedImageGestureState state) {
    final currentScale = state.gestureDetails?.totalScale ?? 1.0;
    final nextScale = currentScale > 1.2 ? 1.0 : 2.5;
    state.handleDoubleTap(
      scale: nextScale,
      doubleTapPosition: state.pointerDownPosition,
    );
  }

  void _precacheAdjacentImages(int index) {
    final cacheService = ref.read(imageCacheServiceProvider);
    for (final candidateIndex in <int>[index - 1, index + 1]) {
      if (candidateIndex < 0 || candidateIndex >= widget.request.items.length) {
        continue;
      }
      final item = widget.request.items[candidateIndex];
      if (!item.isImage) {
        continue;
      }
      precacheImage(cacheService.providerForUrl(item.attachment.url), context);
    }
  }

  void _syncThumbnailRailToPage(double page, {bool animate = false}) {
    if (!mounted || !_thumbnailScrollController.hasClients) {
      return;
    }

    final position = _thumbnailScrollController.position;
    final itemExtent = _thumbnailExtent + _thumbnailSpacing;
    final clampedOffset = (page * itemExtent)
        .clamp(0.0, math.max(position.maxScrollExtent, 0).toDouble())
        .toDouble();

    if ((position.pixels - clampedOffset).abs() < 1) {
      return;
    }

    if (!animate) {
      _thumbnailScrollController.jumpTo(clampedOffset);
      return;
    }

    unawaited(
      _thumbnailScrollController
          .animateTo(
            clampedOffset,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          )
          .catchError((Object _) {
            // Ignore races if the rail is rebuilt while the animation is active.
          }),
    );
  }

  Future<void> _saveCurrentItem() async {
    final l10n = AppLocalizations.of(context)!;
    final attachment = _currentItem.attachment;
    if (_isSaving || attachment.url.isEmpty) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await ref.read(mediaSaveServiceProvider).saveAttachment(attachment);
      _showStatus(
        attachment.isVideo ? l10n.mediaVideoSaved : l10n.mediaImageSaved,
      );
    } on MediaSaveException catch (error) {
      _showStatus(error.message, isError: true);
    } catch (_) {
      _showStatus(l10n.mediaSaveFailed, isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showStatus(String message, {bool isError = false}) {
    _statusTimer?.cancel();
    setState(() {
      _statusMessage = message;
      _statusIsError = isError;
    });
    _statusTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = null;
      });
    });
  }

  Widget _buildViewerChrome(BuildContext context) {
    final title = '${_currentIndex + 1}/${widget.request.items.length}';
    final canSave = _currentItem.attachment.url.isNotEmpty;

    return IgnorePointer(
      ignoring: _isSlidingPage || !_isChromeVisible,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: !_isChromeVisible
            ? const SizedBox.shrink()
            : SafeArea(
                key: const ValueKey('attachment-viewer-chrome'),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(36, 36),
                            onPressed: () => Navigator.of(context).maybePop(),
                            child: const Icon(
                              CupertinoIcons.back,
                              color: CupertinoColors.white,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: CupertinoColors.black.withAlpha(110),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              title,
                              key: const Key('attachment-viewer-count'),
                              style: const TextStyle(
                                color: CupertinoColors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(36, 36),
                            onPressed: canSave ? _saveCurrentItem : null,
                            child: _isSaving
                                ? const CupertinoActivityIndicator(
                                    color: CupertinoColors.white,
                                  )
                                : Icon(
                                    CupertinoIcons.arrow_down_to_line,
                                    color: canSave
                                        ? CupertinoColors.white
                                        : CupertinoColors.systemGrey,
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: _statusMessage == null
                            ? const SizedBox.shrink()
                            : _ViewerStatusBadge(
                                key: ValueKey(_statusMessage),
                                message: _statusMessage!,
                                isError: _statusIsError,
                              ),
                      ),
                      const Spacer(),
                      if (_hasMultipleItems)
                        _ThumbnailRail(
                          controller: _thumbnailScrollController,
                          items: widget.request.items,
                          selectedIndex: _currentIndex,
                          onDragUpdate: (details) {
                            if (!_pageController.hasClients) {
                              return;
                            }
                            final viewport =
                                _pageController.position.viewportDimension;
                            if (viewport <= 0) {
                              return;
                            }
                            final currentPage =
                                _pageController.page ??
                                _currentIndex.toDouble();
                            final targetPage =
                                (currentPage -
                                        ((details.primaryDelta ?? 0) /
                                            viewport))
                                    .clamp(
                                      0.0,
                                      (widget.request.items.length - 1)
                                          .toDouble(),
                                    )
                                    .toDouble();
                            _jumpToPagePosition(targetPage);
                          },
                          onDragEnd: () {
                            final targetIndex =
                                (_pageController.page ??
                                        _currentIndex.toDouble())
                                    .round()
                                    .clamp(0, widget.request.items.length - 1);
                            unawaited(_selectIndex(targetIndex));
                          },
                          onTap: _selectIndex,
                        ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildImagePage(
    BuildContext context,
    AttachmentViewerItem item,
    int index,
  ) {
    final cacheService = ref.watch(imageCacheServiceProvider);
    final provider = cacheService.providerForUrl(item.attachment.url);
    final gestureKey = _gestureKeys[index];
    final mediaPadding = MediaQuery.paddingOf(context);

    return SizedBox.expand(
      child: GestureDetector(
        key: ValueKey('attachment-viewer-media-$index'),
        behavior: HitTestBehavior.opaque,
        onTap: _toggleChrome,
        child: Padding(
          padding: mediaPadding,
          child: Hero(
            tag: item.heroTag,
            child: ExtendedImage(
              image: provider,
              fit: BoxFit.contain,
              mode: ExtendedImageMode.gesture,
              enableLoadState: true,
              enableSlideOutPage: true,
              extendedImageGestureKey: gestureKey,
              initGestureConfigHandler: (state) => GestureConfig(
                minScale: 1.0,
                maxScale: 4.0,
                animationMinScale: 0.95,
                animationMaxScale: 4.5,
                speed: 1.0,
                inertialSpeed: 100.0,
                initialScale: 1.0,
                inPageView: true,
                initialAlignment: InitialAlignment.center,
                gestureDetailsIsChanged: (details) =>
                    _handleGestureDetailsChanged(index, details),
              ),
              onDoubleTap: _handleDoubleTap,
              loadStateChanged: (state) {
                switch (state.extendedImageLoadState) {
                  case LoadState.loading:
                    return const Center(child: CupertinoActivityIndicator());
                  case LoadState.completed:
                    return null;
                  case LoadState.failed:
                    return _ImageLoadError(onRetry: state.reLoadImage);
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPage(AttachmentViewerItem item, int index) {
    return SizedBox.expand(
      child: _VideoViewerPage(
        attachment: item.attachment,
        isActive: index == _currentIndex,
        shouldInitialize: (index - _currentIndex).abs() <= 1,
        hasThumbnailRail: _hasMultipleItems,
        showControls: _isChromeVisible,
        onSurfaceTap: _toggleChrome,
        onBaseScaleChanged: (isAtBaseScale) =>
            _handleVideoBaseScaleChanged(index, isAtBaseScale),
        onError: (message) => _showStatus(message, isError: true),
        surfaceKey: ValueKey('attachment-viewer-media-$index'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.black,
      child: ExtendedImageSlidePage(
        slideAxis: SlideAxis.vertical,
        slideType: SlideType.wholePage,
        slidePageBackgroundHandler: (offset, pageSize) {
          final progress = (offset.dy.abs() / math.max(pageSize.height, 1))
              .clamp(0.0, 1.0);
          return CupertinoColors.black.withValues(alpha: 1 - (progress * 0.6));
        },
        slideEndHandler:
            (
              offset, {
              ExtendedImageSlidePageState? state,
              ScaleEndDetails? details,
            }) {
              if (!_isCurrentItemAtBaseScale && state != null) {
                return false;
              }
              if (state == null) {
                return false;
              }

              final dismissDistance =
                  state.pageSize.height * _dismissDistanceFraction;
              final velocityX = details?.velocity.pixelsPerSecond.dx ?? 0;
              final velocityY = details?.velocity.pixelsPerSecond.dy ?? 0;
              final movedFarEnough = offset.dy.abs() >= dismissDistance;
              final flungFarEnough =
                  velocityY.abs() >= _dismissMinVelocity &&
                  velocityY.abs() > velocityX.abs() * _dismissDirectionBias;

              return movedFarEnough || flungFarEnough;
            },
        onSlidingPage: (state) {
          final nextIsSlidingPage = state.isSliding;
          if (_isSlidingPage == nextIsSlidingPage) {
            return;
          }
          setState(() {
            _isSlidingPage = nextIsSlidingPage;
          });
        },
        child: Stack(
          children: [
            ExtendedImageGesturePageView.builder(
              controller: _pageController,
              itemCount: widget.request.items.length,
              canScrollPage: (_) => _canScrollCurrentPage,
              onPageChanged: _handlePageChanged,
              itemBuilder: (context, index) {
                final item = widget.request.items[index];
                if (item.isVideo) {
                  return _buildVideoPage(item, index);
                }
                return _buildImagePage(context, item, index);
              },
            ),
            _buildViewerChrome(context),
          ],
        ),
      ),
    );
  }
}

class _ThumbnailRail extends StatelessWidget {
  const _ThumbnailRail({
    required this.controller,
    required this.items,
    required this.selectedIndex,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onTap,
  });

  final ScrollController controller;
  final List<AttachmentViewerItem> items;
  final int selectedIndex;
  final GestureDragUpdateCallback onDragUpdate;
  final VoidCallback onDragEnd;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sideInset = math.max(
          ((constraints.maxWidth -
                      _AttachmentViewerPageState._thumbnailExtent) /
                  2) -
              _AttachmentViewerPageState._thumbnailRailHorizontalPadding,
          0,
        );

        return SizedBox(
          height: _AttachmentViewerPageState._thumbnailRailHeight,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragUpdate: onDragUpdate,
            onHorizontalDragEnd: (_) => onDragEnd(),
            onHorizontalDragCancel: onDragEnd,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ListView.separated(
                key: const Key('attachment-viewer-thumbnails'),
                controller: controller,
                physics: const NeverScrollableScrollPhysics(),
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.fromLTRB(
                  sideInset +
                      _AttachmentViewerPageState
                          ._thumbnailRailHorizontalPadding,
                  12,
                  sideInset +
                      _AttachmentViewerPageState
                          ._thumbnailRailHorizontalPadding,
                  12,
                ),
                itemCount: items.length,
                separatorBuilder: (context, index) => const SizedBox(
                  width: _AttachmentViewerPageState._thumbnailSpacing,
                ),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isSelected = index == selectedIndex;

                  return GestureDetector(
                    key: ValueKey('attachment-viewer-thumbnail-$index'),
                    onTap: () => onTap(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: _AttachmentViewerPageState._thumbnailExtent,
                      height: _AttachmentViewerPageState._thumbnailExtent,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? CupertinoColors.white
                              : CupertinoColors.white.withAlpha(64),
                          width: isSelected ? 2 : 1,
                        ),
                        color: CupertinoColors.black.withAlpha(80),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: item.isImage
                            ? AppCachedNetworkImage(
                                imageUrl: item.attachment.url,
                                fit: BoxFit.cover,
                                placeholder: (_, _) => const ColoredBox(
                                  color: CupertinoColors.systemGrey,
                                ),
                                errorWidget: (_, _, _) =>
                                    const _ThumbnailErrorTile(),
                              )
                            : Stack(
                                fit: StackFit.expand,
                                children: [
                                  VideoAttachmentThumbnail(
                                    attachment: item.attachment,
                                  ),
                                  Container(
                                    color: CupertinoColors.black.withAlpha(42),
                                  ),
                                  const Center(
                                    child: Icon(
                                      CupertinoIcons.play_fill,
                                      color: CupertinoColors.white,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ThumbnailErrorTile extends StatelessWidget {
  const _ThumbnailErrorTile();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: CupertinoColors.systemGrey,
      child: Icon(
        CupertinoIcons.exclamationmark_triangle,
        color: CupertinoColors.white,
      ),
    );
  }
}

class _ViewerStatusBadge extends StatelessWidget {
  const _ViewerStatusBadge({
    super.key,
    required this.message,
    required this.isError,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isError
            ? const Color(0xC9A83232)
            : CupertinoColors.black.withAlpha(140),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: CupertinoColors.white,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _VideoViewerPage extends StatefulWidget {
  const _VideoViewerPage({
    required this.attachment,
    required this.isActive,
    required this.shouldInitialize,
    required this.hasThumbnailRail,
    required this.showControls,
    required this.onSurfaceTap,
    required this.onBaseScaleChanged,
    required this.onError,
    required this.surfaceKey,
  });

  final AttachmentItem attachment;
  final bool isActive;
  final bool shouldInitialize;
  final bool hasThumbnailRail;
  final bool showControls;
  final VoidCallback onSurfaceTap;
  final ValueChanged<bool> onBaseScaleChanged;
  final ValueChanged<String> onError;
  final Key surfaceKey;

  @override
  State<_VideoViewerPage> createState() => _VideoViewerPageState();
}

class _VideoViewerPageState extends State<_VideoViewerPage> {
  static const double _videoMaxScale = 4;
  static const double _videoDoubleTapScale = 2.5;
  static const double _videoScaleTolerance = 0.02;
  static const double _reservedBottomGap = 12;
  static const double _dismissGestureMinDelta = 10;
  static const double _dismissDirectionBias = 1.2;

  VideoPlayerController? _controller;
  ExtendedImageSlidePageState? _slidePageState;
  late final TransformationController _transformationController;
  Object? _initializationError;
  var _isInitializing = false;
  TapDownDetails? _doubleTapDetails;
  var _isAtBaseScale = true;
  final Set<int> _activePointers = <int>{};
  final List<_PointerSample> _verticalDismissSamples = <_PointerSample>[];
  Offset? _verticalDismissStart;
  Offset? _verticalDismissLastGlobalPosition;
  Rect? _mediaViewportRect;
  Size _videoViewportSize = Size.zero;
  Size _videoContentSize = Size.zero;
  bool _isTrackingVerticalDismiss = false;
  bool _isApplyingTransform = false;
  double _lastGestureScale = 1;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _transformationController.addListener(_handleTransformChanged);
    if (widget.shouldInitialize) {
      unawaited(_ensureInitialized());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      widget.onBaseScaleChanged(true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _slidePageState = context
        .findAncestorStateOfType<ExtendedImageSlidePageState>();
  }

  @override
  void didUpdateWidget(covariant _VideoViewerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shouldInitialize && _controller == null && !_isInitializing) {
      unawaited(_ensureInitialized());
    }
    if (!widget.isActive && oldWidget.isActive) {
      unawaited(_controller?.pause() ?? Future<void>.value());
      _resetTransform();
    } else if (widget.isActive && !oldWidget.isActive) {
      unawaited(_playIfReady());
    }
  }

  @override
  void dispose() {
    _transformationController.removeListener(_handleTransformChanged);
    _transformationController.dispose();
    _controller?.dispose();
    super.dispose();
  }

  void _handleTransformChanged() {
    if (_isApplyingTransform) {
      return;
    }

    final normalizedTransform = _normalizedVideoTransform(
      transform: _transformationController.value,
      viewportSize: _videoViewportSize,
      contentSize: _videoContentSize,
      scaleTolerance: _videoScaleTolerance,
    );

    if (!_matrixCloseTo(_transformationController.value, normalizedTransform)) {
      _applyTransform(normalizedTransform);
      return;
    }

    _syncBaseScaleState(normalizedTransform);
  }

  void _applyTransform(Matrix4 transform) {
    final normalizedTransform = _normalizedVideoTransform(
      transform: transform,
      viewportSize: _videoViewportSize,
      contentSize: _videoContentSize,
      scaleTolerance: _videoScaleTolerance,
    );
    _isApplyingTransform = true;
    _transformationController.value = normalizedTransform;
    _isApplyingTransform = false;
    _syncBaseScaleState(normalizedTransform);
  }

  void _normalizeTransform() {
    if (_videoViewportSize.isEmpty || _videoContentSize.isEmpty) {
      return;
    }
    final normalizedTransform = _normalizedVideoTransform(
      transform: _transformationController.value,
      viewportSize: _videoViewportSize,
      contentSize: _videoContentSize,
      scaleTolerance: _videoScaleTolerance,
    );
    if (_matrixCloseTo(_transformationController.value, normalizedTransform)) {
      return;
    }
    _applyTransform(normalizedTransform);
  }

  void _syncBaseScaleState(Matrix4 transform) {
    final nextIsAtBaseScale = _isVideoAtBaseScale(
      transform: transform,
      viewportSize: _videoViewportSize,
      contentSize: _videoContentSize,
      scaleTolerance: _videoScaleTolerance,
    );
    if (_isAtBaseScale == nextIsAtBaseScale) {
      return;
    }
    setState(() {
      _isAtBaseScale = nextIsAtBaseScale;
    });
    widget.onBaseScaleChanged(nextIsAtBaseScale);
  }

  void _handlePointerDown(PointerDownEvent event) {
    _activePointers.add(event.pointer);
    if (_activePointers.length > 1) {
      _cancelVerticalDismissTracking();
      return;
    }
    _verticalDismissSamples
      ..clear()
      ..add(_PointerSample(event.timeStamp, event.position));
    _verticalDismissStart = event.position;
    _verticalDismissLastGlobalPosition = event.position;
    _isTrackingVerticalDismiss = false;
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_activePointers.contains(event.pointer)) {
      return;
    }
    _verticalDismissSamples.add(
      _PointerSample(event.timeStamp, event.position),
    );
    if (_activePointers.length != 1) {
      return;
    }

    final lastGlobalPosition = _verticalDismissLastGlobalPosition;
    if (!_isAtBaseScale) {
      if (lastGlobalPosition == null) {
        _verticalDismissLastGlobalPosition = event.position;
        return;
      }
      final delta = event.position - lastGlobalPosition;
      final nextTransform = Matrix4.copy(_transformationController.value)
        ..translateByDouble(delta.dx, delta.dy, 0, 1);
      _applyTransform(
        _normalizedVideoTransform(
          transform: nextTransform,
          viewportSize: _videoViewportSize,
          contentSize: _videoContentSize,
          scaleTolerance: _videoScaleTolerance,
        ),
      );
      _verticalDismissLastGlobalPosition = event.position;
      return;
    }

    final slidePageState = _slidePageState;
    final start = _verticalDismissStart;
    if (slidePageState == null || start == null || lastGlobalPosition == null) {
      return;
    }

    final totalDelta = event.position - start;
    if (!_isTrackingVerticalDismiss) {
      if (totalDelta.distance < _dismissGestureMinDelta) {
        _verticalDismissLastGlobalPosition = event.position;
        return;
      }
      final verticalDominant =
          totalDelta.dy.abs() > totalDelta.dx.abs() * _dismissDirectionBias;
      if (!verticalDominant) {
        _verticalDismissLastGlobalPosition = event.position;
        return;
      }
      _isTrackingVerticalDismiss = true;
    }

    slidePageState.slide(Offset(0, event.position.dy - lastGlobalPosition.dy));
    _verticalDismissLastGlobalPosition = event.position;
  }

  void _handlePointerUp(PointerUpEvent event) {
    _verticalDismissSamples.add(
      _PointerSample(event.timeStamp, event.position),
    );
    _finishPointer(event.pointer);
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _finishPointer(event.pointer);
  }

  void _finishPointer(int pointer) {
    _activePointers.remove(pointer);
    if (_activePointers.isNotEmpty) {
      return;
    }

    final slidePageState = _slidePageState;
    if (_isTrackingVerticalDismiss &&
        slidePageState != null &&
        slidePageState.isSliding) {
      slidePageState.endSlide(
        ScaleEndDetails(velocity: _estimateVerticalDismissVelocity()),
      );
    }
    _cancelVerticalDismissTracking();
  }

  void _cancelVerticalDismissTracking() {
    _verticalDismissSamples.clear();
    _verticalDismissStart = null;
    _verticalDismissLastGlobalPosition = null;
    _isTrackingVerticalDismiss = false;
  }

  Velocity _estimateVerticalDismissVelocity() {
    if (_verticalDismissSamples.length < 2) {
      return Velocity.zero;
    }

    final latest = _verticalDismissSamples.last;
    _PointerSample earliest = latest;

    for (var i = _verticalDismissSamples.length - 2; i >= 0; i--) {
      final candidate = _verticalDismissSamples[i];
      if ((latest.timeStamp - candidate.timeStamp).inMilliseconds > 80) {
        break;
      }
      earliest = candidate;
    }

    final elapsed = latest.timeStamp - earliest.timeStamp;
    if (elapsed.inMicroseconds <= 0) {
      return Velocity.zero;
    }

    final seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final delta = latest.position - earliest.position;
    return Velocity(pixelsPerSecond: delta / seconds);
  }

  void _resetTransform() {
    _applyTransform(
      _videoBaseTransform(
        viewportSize: _videoViewportSize,
        contentSize: _videoContentSize,
      ),
    );
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleScaleStart(ScaleStartDetails details) {
    if (_activePointers.length < 2) {
      return;
    }
    _lastGestureScale = 1;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount < 2 ||
        _videoViewportSize.isEmpty ||
        _videoContentSize.isEmpty) {
      return;
    }

    final mediaViewportRect = _mediaViewportRect;
    if (mediaViewportRect == null) {
      return;
    }

    final scaleDelta = details.scale / _lastGestureScale;
    _lastGestureScale = details.scale;
    if (scaleDelta <= 0) {
      return;
    }

    final currentTransform = _transformationController.value;
    final currentScale = currentTransform.getMaxScaleOnAxis();
    final targetScale = (currentScale * scaleDelta).clamp(1.0, _videoMaxScale);
    if ((targetScale - currentScale).abs() <= _videoScaleTolerance / 4 &&
        details.focalPointDelta.distance <= 0) {
      return;
    }

    final viewportFocalPoint =
        details.localFocalPoint - mediaViewportRect.topLeft;
    _applyTransform(
      _anchoredVideoTransform(
        baseTransform: currentTransform,
        viewportFocalPoint: viewportFocalPoint,
        targetScale: targetScale,
        viewportSize: _videoViewportSize,
        contentSize: _videoContentSize,
        scaleTolerance: _videoScaleTolerance,
      ),
    );
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    _lastGestureScale = 1;
    _normalizeTransform();
  }

  void _handleDoubleTap() {
    final details = _doubleTapDetails;
    final mediaViewportRect = _mediaViewportRect;
    if (details == null || mediaViewportRect == null) {
      return;
    }
    final tapPosition = details.globalPosition - mediaViewportRect.topLeft;
    if (!_isAtBaseScale) {
      _resetTransform();
      return;
    }
    final baseTranslation = _videoBaseTranslation(
      viewportSize: _videoViewportSize,
      contentSize: _videoContentSize,
    );
    final clampedTapPosition = Offset(
      tapPosition.dx.clamp(
        baseTranslation.dx,
        baseTranslation.dx + _videoContentSize.width,
      ),
      tapPosition.dy.clamp(
        baseTranslation.dy,
        baseTranslation.dy + _videoContentSize.height,
      ),
    );
    _applyTransform(
      _anchoredVideoTransform(
        baseTransform: _videoBaseTransform(
          viewportSize: _videoViewportSize,
          contentSize: _videoContentSize,
        ),
        viewportFocalPoint: clampedTapPosition,
        targetScale: _videoDoubleTapScale,
        viewportSize: _videoViewportSize,
        contentSize: _videoContentSize,
        scaleTolerance: _videoScaleTolerance,
      ),
    );
  }

  Future<void> _ensureInitialized() async {
    if (_controller != null ||
        _isInitializing ||
        widget.attachment.url.isEmpty) {
      return;
    }

    setState(() {
      _isInitializing = true;
      _initializationError = null;
    });

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.attachment.url),
      httpHeaders: ApiSession.authHeaders,
    );

    try {
      await controller.initialize();
      await controller.setVolume(1);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _isInitializing = false;
      });
      if (widget.isActive) {
        await controller.play();
      }
    } catch (error) {
      await controller.dispose();
      if (!mounted) {
        return;
      }
      setState(() {
        _initializationError = error;
        _isInitializing = false;
      });
    }
  }

  Future<void> _playIfReady() async {
    final controller = _controller;
    if (controller == null) {
      await _ensureInitialized();
      return;
    }
    if (!controller.value.isInitialized) {
      return;
    }
    if (controller.value.position >= controller.value.duration) {
      await controller.seekTo(Duration.zero);
    }
    await controller.play();
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null) {
      await _ensureInitialized();
      return;
    }
    if (!controller.value.isInitialized) {
      return;
    }
    if (controller.value.isPlaying) {
      await controller.pause();
      return;
    }
    if (controller.value.position >= controller.value.duration) {
      await controller.seekTo(Duration.zero);
    }
    await controller.play();
  }

  Future<void> _retry() async {
    await _controller?.dispose();
    if (!mounted) {
      return;
    }
    setState(() {
      _controller = null;
      _initializationError = null;
    });
    _resetTransform();
    await _ensureInitialized();
    if (_initializationError != null) {
      widget.onError('Failed to load video.');
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (_initializationError != null) {
      child = _VideoLoadError(onRetry: _retry);
    } else if (_isInitializing || _controller == null) {
      child = const Center(child: CupertinoActivityIndicator());
    } else {
      final controller = _controller!;
      final aspectRatio = controller.value.isInitialized
          ? controller.value.aspectRatio
          : _preferredAspectRatio(widget.attachment);
      child = LayoutBuilder(
        builder: (context, constraints) {
          final mediaPadding = MediaQuery.paddingOf(context);
          final mediaViewportRect = _safeMediaViewportRect(
            availableSize: Size(constraints.maxWidth, constraints.maxHeight),
            mediaPadding: mediaPadding,
          );
          _mediaViewportRect = mediaViewportRect;
          final fittedSize = _fittedVideoSize(
            viewportSize: mediaViewportRect.size,
            aspectRatio: aspectRatio,
          );
          final viewportSize = mediaViewportRect.size;
          final geometryChanged =
              viewportSize != _videoViewportSize ||
              fittedSize != _videoContentSize;
          _videoViewportSize = viewportSize;
          _videoContentSize = fittedSize;
          if (geometryChanged) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) {
                return;
              }
              _normalizeTransform();
            });
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fromRect(
                rect: mediaViewportRect,
                child: ClipRect(
                  key: const Key('attachment-viewer-video-viewport'),
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    panEnabled: false,
                    scaleEnabled: false,
                    minScale: 1,
                    maxScale: _videoMaxScale,
                    constrained: false,
                    alignment: Alignment.topLeft,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      key: const Key('attachment-viewer-video-content'),
                      width: fittedSize.width,
                      height: fittedSize.height,
                      child: ColoredBox(
                        color: CupertinoColors.black,
                        child: FittedBox(
                          fit: BoxFit.fill,
                          child: SizedBox(
                            width: controller.value.size.width,
                            height: controller.value.size.height,
                            child: VideoPlayer(controller),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: _handlePointerDown,
                  onPointerMove: _handlePointerMove,
                  onPointerUp: _handlePointerUp,
                  onPointerCancel: _handlePointerCancel,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: widget.onSurfaceTap,
                    onScaleStart: _handleScaleStart,
                    onScaleUpdate: _handleScaleUpdate,
                    onScaleEnd: _handleScaleEnd,
                    onDoubleTapDown: _handleDoubleTapDown,
                    onDoubleTap: _handleDoubleTap,
                  ),
                ),
              ),
              Positioned.fill(
                child: ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: controller,
                  builder: (context, value, child) {
                    final bottomControlsInset = _videoBottomControlsInset(
                      mediaPadding: mediaPadding,
                      hasThumbnailRail: widget.hasThumbnailRail,
                    );

                    return Stack(
                      children: [
                        if (widget.showControls)
                          Positioned.fromRect(
                            rect: mediaViewportRect,
                            child: Center(
                              child: CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: _togglePlayback,
                                child: Container(
                                  width: 68,
                                  height: 68,
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.black.withAlpha(130),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Icon(
                                    value.isPlaying
                                        ? CupertinoIcons.pause_fill
                                        : CupertinoIcons.play_fill,
                                    color: CupertinoColors.white,
                                    size: 34,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: bottomControlsInset,
                          child: AnimatedOpacity(
                            key: const Key('attachment-viewer-video-progress'),
                            duration: const Duration(milliseconds: 180),
                            opacity: widget.showControls ? 1 : 0,
                            child: IgnorePointer(
                              ignoring: !widget.showControls,
                              child: Container(
                                color: CupertinoColors.black.withAlpha(68),
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  8,
                                  12,
                                  12,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      _formatPlaybackTime(value.position),
                                      key: const Key(
                                        'attachment-viewer-video-elapsed',
                                      ),
                                      style: const TextStyle(
                                        color: CupertinoColors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: VideoProgressIndicator(
                                        controller,
                                        allowScrubbing: true,
                                        colors: VideoProgressColors(
                                          playedColor: CupertinoColors.white,
                                          bufferedColor:
                                              CupertinoColors.systemGrey,
                                          backgroundColor:
                                              CupertinoColors.systemGrey4,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      _formatRemainingPlaybackTime(
                                        value.position,
                                        value.duration,
                                      ),
                                      key: const Key(
                                        'attachment-viewer-video-remaining',
                                      ),
                                      style: const TextStyle(
                                        color: CupertinoColors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      );
    }

    return KeyedSubtree(key: widget.surfaceKey, child: child);
  }
}

class _ImageLoadError extends StatelessWidget {
  const _ImageLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.exclamationmark_triangle,
              size: 36,
              color: CupertinoColors.white,
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.mediaImageLoadFailed,
              style: TextStyle(
                color: CupertinoColors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            CupertinoButton.filled(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context)!.retry),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoLoadError extends StatelessWidget {
  const _VideoLoadError({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.play_rectangle,
              color: CupertinoColors.white,
              size: 40,
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.mediaVideoLoadFailed,
              style: TextStyle(
                color: CupertinoColors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            CupertinoButton.filled(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context)!.retry),
            ),
          ],
        ),
      ),
    );
  }
}

class _PointerSample {
  const _PointerSample(this.timeStamp, this.position);

  final Duration timeStamp;
  final Offset position;
}

double _preferredAspectRatio(AttachmentItem attachment) {
  final width = attachment.width;
  final height = attachment.height;
  if (width != null && height != null && width > 0 && height > 0) {
    return width / height;
  }
  return 16 / 9;
}

Size _fittedVideoSize({
  required Size viewportSize,
  required double aspectRatio,
}) {
  if (viewportSize.width <= 0 || viewportSize.height <= 0) {
    return Size.zero;
  }
  if (aspectRatio <= 0) {
    return viewportSize;
  }

  final viewportAspectRatio = viewportSize.width / viewportSize.height;
  if (viewportAspectRatio > aspectRatio) {
    final height = viewportSize.height;
    return Size(height * aspectRatio, height);
  }

  final width = viewportSize.width;
  return Size(width, width / aspectRatio);
}

Matrix4 _normalizedVideoTransform({
  required Matrix4 transform,
  required Size viewportSize,
  required Size contentSize,
  required double scaleTolerance,
}) {
  if (viewportSize.isEmpty || contentSize.isEmpty) {
    return Matrix4.identity();
  }

  final scale = transform.getMaxScaleOnAxis();
  if ((scale - 1).abs() <= scaleTolerance) {
    return _videoBaseTransform(
      viewportSize: viewportSize,
      contentSize: contentSize,
    );
  }

  final translationX = transform.storage[12];
  final translationY = transform.storage[13];
  final clampedTranslation = Offset(
    _clampedVideoAxisTranslation(
      translation: translationX,
      scale: scale,
      viewportExtent: viewportSize.width,
      contentExtent: contentSize.width,
    ),
    _clampedVideoAxisTranslation(
      translation: translationY,
      scale: scale,
      viewportExtent: viewportSize.height,
      contentExtent: contentSize.height,
    ),
  );

  return Matrix4.identity()
    ..translateByDouble(clampedTranslation.dx, clampedTranslation.dy, 0, 1)
    ..scaleByDouble(scale, scale, 1, 1);
}

Matrix4 _anchoredVideoTransform({
  required Matrix4 baseTransform,
  required Offset viewportFocalPoint,
  required double targetScale,
  required Size viewportSize,
  required Size contentSize,
  required double scaleTolerance,
}) {
  if (viewportSize.isEmpty || contentSize.isEmpty) {
    return Matrix4.identity();
  }

  final clampedScale = targetScale.clamp(
    1.0,
    _VideoViewerPageState._videoMaxScale,
  );
  if ((clampedScale - 1).abs() <= scaleTolerance) {
    return _videoBaseTransform(
      viewportSize: viewportSize,
      contentSize: contentSize,
    );
  }

  final contentAnchor = _contentPointForViewportPoint(
    transform: baseTransform,
    viewportPoint: viewportFocalPoint,
  );
  final anchoredTranslation = Offset(
    viewportFocalPoint.dx - (contentAnchor.dx * clampedScale),
    viewportFocalPoint.dy - (contentAnchor.dy * clampedScale),
  );
  final anchoredTransform = Matrix4.identity()
    ..translateByDouble(anchoredTranslation.dx, anchoredTranslation.dy, 0, 1)
    ..scaleByDouble(clampedScale, clampedScale, 1, 1);

  return _normalizedVideoTransform(
    transform: anchoredTransform,
    viewportSize: viewportSize,
    contentSize: contentSize,
    scaleTolerance: scaleTolerance,
  );
}

double _clampedVideoAxisTranslation({
  required double translation,
  required double scale,
  required double viewportExtent,
  required double contentExtent,
}) {
  if (viewportExtent <= 0 || contentExtent <= 0) {
    return 0;
  }

  final scaledContentExtent = contentExtent * scale;
  if (scaledContentExtent <= viewportExtent) {
    return (viewportExtent - scaledContentExtent) / 2;
  }

  final minTranslation = viewportExtent - scaledContentExtent;
  final maxTranslation = 0.0;
  return translation.clamp(minTranslation, maxTranslation).toDouble();
}

Matrix4 _videoBaseTransform({
  required Size viewportSize,
  required Size contentSize,
}) {
  final translation = _videoBaseTranslation(
    viewportSize: viewportSize,
    contentSize: contentSize,
  );
  return Matrix4.identity()
    ..translateByDouble(translation.dx, translation.dy, 0, 1);
}

Offset _videoBaseTranslation({
  required Size viewportSize,
  required Size contentSize,
}) {
  if (viewportSize.isEmpty || contentSize.isEmpty) {
    return Offset.zero;
  }

  return Offset(
    ((viewportSize.width - contentSize.width) / 2).toDouble(),
    ((viewportSize.height - contentSize.height) / 2).toDouble(),
  );
}

Offset _contentPointForViewportPoint({
  required Matrix4 transform,
  required Offset viewportPoint,
}) {
  final scale = transform.getMaxScaleOnAxis();
  if (scale <= 0) {
    return viewportPoint;
  }

  final translationX = transform.storage[12];
  final translationY = transform.storage[13];
  return Offset(
    (viewportPoint.dx - translationX) / scale,
    (viewportPoint.dy - translationY) / scale,
  );
}

bool _matrixCloseTo(Matrix4 left, Matrix4 right, {double tolerance = 0.01}) {
  for (var index = 0; index < left.storage.length; index++) {
    if ((left.storage[index] - right.storage[index]).abs() > tolerance) {
      return false;
    }
  }
  return true;
}

bool _isVideoAtBaseScale({
  required Matrix4 transform,
  required Size viewportSize,
  required Size contentSize,
  required double scaleTolerance,
}) {
  return (transform.getMaxScaleOnAxis() - 1).abs() <= scaleTolerance &&
      _matrixCloseTo(
        transform,
        _videoBaseTransform(
          viewportSize: viewportSize,
          contentSize: contentSize,
        ),
      );
}

Rect _safeMediaViewportRect({
  required Size availableSize,
  required EdgeInsets mediaPadding,
}) {
  final width = math
      .max(availableSize.width - mediaPadding.left - mediaPadding.right, 0.0)
      .toDouble();
  final height = math
      .max(availableSize.height - mediaPadding.top - mediaPadding.bottom, 0.0)
      .toDouble();
  return Rect.fromLTWH(mediaPadding.left, mediaPadding.top, width, height);
}

double _videoBottomControlsInset({
  required EdgeInsets mediaPadding,
  required bool hasThumbnailRail,
}) {
  final railHeight = hasThumbnailRail
      ? _AttachmentViewerPageState._thumbnailRailHeight
      : 0.0;
  return mediaPadding.bottom +
      railHeight +
      _VideoViewerPageState._reservedBottomGap;
}

String _formatPlaybackTime(Duration duration) {
  final totalSeconds = math.max(duration.inSeconds, 0);
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

String _formatRemainingPlaybackTime(Duration position, Duration duration) {
  final remaining = duration - position;
  final clampedRemaining = remaining.isNegative ? Duration.zero : remaining;
  return '-${_formatPlaybackTime(clampedRemaining)}';
}
