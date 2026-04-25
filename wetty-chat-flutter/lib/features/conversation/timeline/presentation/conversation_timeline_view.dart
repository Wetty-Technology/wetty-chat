import 'dart:async';
import 'dart:developer';

import 'package:chahua/app/routing/route_names.dart';
import 'package:chahua/features/conversation/compose/presentation/conversation_composer_view_model.dart';
import 'package:chahua/features/conversation/media/presentation/attachment_viewer_request.dart';
import 'package:chahua/features/conversation/timeline/presentation/conversation_timeline_view_model.dart';
import 'package:chahua/features/shared/model/message/message.dart';
import 'package:chahua/features/conversation/shared/domain/conversation_identity.dart';
import 'package:chahua/features/conversation/shared/domain/launch_request.dart';
import 'package:chahua/features/conversation/timeline/presentation/message_long_press_details_v2.dart';
import 'package:chahua/features/conversation/timeline/presentation/message_overlay_v2.dart';
import 'package:chahua/features/conversation/message_bubble/presentation/message_row_v2.dart';
import 'package:chahua/core/session/dev_session_store.dart';
import 'package:chahua/features/conversation/timeline/presentation/parts/jump_to_latest_fab.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  log(
    'resolveTopPreferredAnchorAlignment: afterExtent=$afterExtent, viewportExtent=$viewportExtent, visibleFractionBelowAnchor=$visibleFractionBelowAnchor',
  );
  return 1.0 - visibleFractionBelowAnchor;
}

int? _resolveLastVisibleMessageIdAtViewportMidpoint({
  required Iterable<({int? messageId, double top, double bottom})> measurements,
  required double viewportTop,
  required double viewportBottom,
}) {
  if (viewportBottom <= viewportTop) {
    return null;
  }

  int? lastVisibleMessageId;
  double? lastVisibleTop;
  double? lastVisibleBottom;

  for (final measurement in measurements) {
    final messageId = measurement.messageId;
    if (messageId == null) {
      continue;
    }

    final visibleTop = measurement.top.clamp(viewportTop, viewportBottom);
    final visibleBottom = measurement.bottom.clamp(viewportTop, viewportBottom);
    if (visibleBottom <= visibleTop) {
      continue;
    }

    final bubbleMidpoint = (measurement.top + measurement.bottom) / 2;
    if (bubbleMidpoint < viewportTop || bubbleMidpoint > viewportBottom) {
      continue;
    }

    if (lastVisibleTop == null ||
        visibleTop > lastVisibleTop ||
        (visibleTop == lastVisibleTop &&
            (lastVisibleBottom == null || visibleBottom > lastVisibleBottom))) {
      lastVisibleMessageId = messageId;
      lastVisibleTop = visibleTop;
      lastVisibleBottom = visibleBottom;
    }
  }

  return lastVisibleMessageId;
}

class ConversationTimelineView extends ConsumerStatefulWidget {
  const ConversationTimelineView({
    super.key,
    required this.chatId,
    required this.launchRequest,
    this.threadRootId,
    this.onOpenThread,
    this.onStartThread,
  });

  final int chatId;
  final int? threadRootId;
  final LaunchRequest launchRequest;
  final void Function(ConversationMessageV2 message)? onOpenThread;
  final void Function(ConversationMessageV2 message)? onStartThread;

  @override
  ConsumerState<ConversationTimelineView> createState() =>
      _ConversationTimelineViewState();
}

class _ConversationTimelineViewState
    extends ConsumerState<ConversationTimelineView> {
  static const double _edgeThreshold = 80;
  static const double _jumpToLatestInset = 16;
  static const List<String> _quickReactionEmojis = <String>[
    '👍',
    '❤️',
    '😂',
    '😮',
    '😢',
  ];

  late ScrollController _scrollController;
  int _lastHandledViewportCommandGeneration = 0;
  final GlobalKey _centerSliverKey = GlobalKey();
  final GlobalKey _afterContentSliverKey = GlobalKey();
  final Map<String, GlobalKey> _messageKeys = <String, GlobalKey>{};
  bool _isMeasureScheduled = false;
  double _topPreferredAnchorAlignment = 0;
  bool _isTopPreferredAnchorResolved = false;
  UniqueKey _scrollViewKey = UniqueKey();
  MessageLongPressDetailsV2? _activeOverlay;
  TimelineViewportFacts _latestViewportFacts = const TimelineViewportFacts();
  Map<String, ConversationMessageV2> _renderedMessagesByStableKey =
      const <String, ConversationMessageV2>{};
  bool _isViewportMeasurementScheduled = false;
  int? _lastVisibleMessageId;

  ConversationIdentity get _identity =>
      (chatId: widget.chatId, threadRootId: widget.threadRootId);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_handleScrollChanged);
    _scheduleInitializeLaunchRequest();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScrollChanged);
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleTopPreferredMeasurement({bool resetResolution = false}) {
    if (resetResolution) {
      _topPreferredAnchorAlignment = 0;
      _isTopPreferredAnchorResolved = false;
    }
    if (_isMeasureScheduled) {
      return;
    }
    _isMeasureScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isMeasureScheduled = false;
      if (!mounted) {
        return;
      }

      final renderObject = _afterContentSliverKey.currentContext
          ?.findRenderObject();
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
        afterExtent: afterExtent,
        viewportExtent: viewportExtent,
      );
      if ((nextAlignment - _topPreferredAnchorAlignment).abs() < 0.001 &&
          _isTopPreferredAnchorResolved) {
        return;
      }
      setState(() {
        _topPreferredAnchorAlignment = nextAlignment;
        _isTopPreferredAnchorResolved = true;
      });
    });
  }

  @override
  void didUpdateWidget(covariant ConversationTimelineView oldWidget) {
    super.didUpdateWidget(oldWidget);
    debugPrint('didUpdateWidget: ConversationTimelinV2');
    if (oldWidget.chatId != widget.chatId ||
        oldWidget.threadRootId != widget.threadRootId) {
      _lastHandledViewportCommandGeneration = 0;
      _lastVisibleMessageId = null;
    }
    if (oldWidget.launchRequest != widget.launchRequest) {
      _scheduleInitializeLaunchRequest();
    }
  }

  void _scheduleInitializeLaunchRequest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      ref
          .read(conversationTimelineViewModelProvider(_identity).notifier)
          .initialize(widget.launchRequest);
    });
  }

  void _handleScrollChanged() {
    _updateViewportFacts();
    _updateLastVisibleMessageId();
  }

  void _scheduleViewportMeasurement() {
    if (_isViewportMeasurementScheduled) {
      return;
    }
    _isViewportMeasurementScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isViewportMeasurementScheduled = false;
      if (!mounted) {
        return;
      }
      _updateViewportFacts();
      _updateLastVisibleMessageId();
    });
  }

  /// Reports the viewport facts to the view model.
  void _updateViewportFacts() {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;
    final facts = TimelineViewportFacts(
      isNearTop: (position.pixels - position.minScrollExtent) <= _edgeThreshold,
      isNearBottom:
          (position.maxScrollExtent - position.pixels) <= _edgeThreshold,
    );

    if (facts != _latestViewportFacts) {
      setState(() {
        _latestViewportFacts = facts;
      });

      ref
          .read(conversationTimelineViewModelProvider(_identity).notifier)
          .onViewportChanged(facts);
    }
  }

  void _updateLastVisibleMessageId() {
    if (!_scrollController.hasClients || _renderedMessagesByStableKey.isEmpty) {
      return;
    }

    final viewportBox = context.findRenderObject();
    if (viewportBox is! RenderBox) {
      return;
    }

    final viewportTopLeft = viewportBox.localToGlobal(Offset.zero);
    final viewportTop = viewportTopLeft.dy;
    final viewportBottom = viewportTop + viewportBox.size.height;
    final measurements = <({int? messageId, double top, double bottom})>[];

    for (final entry in _renderedMessagesByStableKey.entries) {
      final renderObject = _messageKeys[entry.key]?.currentContext
          ?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.attached) {
        continue;
      }

      final topLeft = renderObject.localToGlobal(Offset.zero);
      measurements.add((
        messageId: entry.value.serverMessageId,
        top: topLeft.dy,
        bottom: topLeft.dy + renderObject.size.height,
      ));
    }

    final nextLastVisibleMessageId =
        _resolveLastVisibleMessageIdAtViewportMidpoint(
          measurements: measurements,
          viewportTop: viewportTop,
          viewportBottom: viewportBottom,
        );
    if (nextLastVisibleMessageId == _lastVisibleMessageId) {
      return;
    }

    setState(() {
      _lastVisibleMessageId = nextLastVisibleMessageId;
    });

    if (nextLastVisibleMessageId != null) {
      ref
          .read(conversationTimelineViewModelProvider(_identity).notifier)
          .reportLastVisibleMessageId(nextLastVisibleMessageId);
    }
  }

  /// This method is meant to be called by the build method synchronously,
  void _consumeViewportCommand(ConversationTimelineState state) {
    final generation = state.viewportCommandGeneration;
    if (generation <= _lastHandledViewportCommandGeneration) {
      return;
    }

    log(
      'consumeViewportCommand: generation=$generation, kind=${state.viewportCommand.kind}, placement=${state.viewportCommand.placement}',
    );

    _lastHandledViewportCommandGeneration = generation;

    // If we are here, we have a new viewport command to execute.

    switch (state.viewportCommand.kind) {
      case ConversationTimelineViewportCommandKind.none:
        // Nothing to do
        break;
      case ConversationTimelineViewportCommandKind.resetToCenterOrigin:
        // There are two cases for this, for now we are not caring, just forcing a new scrollable.
        _scrollViewKey = UniqueKey();
        if (state.viewportCommand.placement ==
            ConversationTimelineViewportPlacement.topPreferred) {
          _scheduleTopPreferredMeasurement(resetResolution: true);
        }
        break;
      case ConversationTimelineViewportCommandKind.scrollToBottom:
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
        break;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduleViewportMeasurement();
    });
  }

  Future<void> _scrollToBottom() async {
    if (!mounted || !_scrollController.hasClients) {
      return;
    }

    await _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _openMessageOverlay(MessageLongPressDetailsV2 details) {
    if (details.message.isDeleted) {
      return;
    }
    final viewportBox = context.findRenderObject();
    if (viewportBox is! RenderBox || !viewportBox.attached) {
      return;
    }
    final viewportGlobalOrigin = viewportBox.localToGlobal(Offset.zero);
    final viewportGlobalRect = viewportGlobalOrigin & viewportBox.size;
    final bubbleGlobalRect = details.bubbleRect;
    final visibleGlobalRect = bubbleGlobalRect.intersect(viewportGlobalRect);
    if (visibleGlobalRect.isEmpty) {
      return;
    }
    setState(() {
      _activeOverlay = details.copyWith(
        bubbleRect: bubbleGlobalRect.shift(-viewportGlobalOrigin),
        visibleRect: visibleGlobalRect.shift(-viewportGlobalOrigin),
      );
    });
  }

  void _dismissMessageOverlay() {
    if (_activeOverlay == null) {
      return;
    }
    setState(() {
      _activeOverlay = null;
    });
  }

  Future<void> _toggleReaction(
    ConversationMessageV2 message,
    String emoji,
  ) async {
    try {
      await ref
          .read(conversationTimelineViewModelProvider(_identity).notifier)
          .toggleReaction(message, emoji);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showErrorDialog('$error');
    }
  }

  Future<void> _deleteMessage(ConversationMessageV2 message) async {
    try {
      await ref
          .read(conversationTimelineViewModelProvider(_identity).notifier)
          .deleteMessage(message);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showErrorDialog('$error');
    }
  }

  void _confirmDelete(ConversationMessageV2 message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(context);
              unawaited(_deleteMessage(message));
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _openAttachment(MessageAttachmentOpenRequest request) {
    final viewerRequest = request.viewerRequest;
    if (viewerRequest == null) {
      return;
    }
    context.push(AppRoutes.attachmentViewer, extra: viewerRequest);
  }

  Map<String, ({bool showSenderName, bool showAvatar})> _buildRowPresentation(
    List<ConversationMessageV2> orderedMessages,
  ) {
    final presentationByStableKey =
        <String, ({bool showSenderName, bool showAvatar})>{};

    for (var index = 0; index < orderedMessages.length; index++) {
      final message = orderedMessages[index];
      if (message.content is SystemMessageContent) {
        presentationByStableKey[message.stableKey] = const (
          showSenderName: false,
          showAvatar: false,
        );
        continue;
      }

      final previousMessage = index > 0 ? orderedMessages[index - 1] : null;
      final nextMessage = index < orderedMessages.length - 1
          ? orderedMessages[index + 1]
          : null;

      final showSenderName =
          previousMessage == null ||
          previousMessage.content is SystemMessageContent ||
          previousMessage.sender.uid != message.sender.uid;
      final showAvatar =
          nextMessage == null ||
          nextMessage.content is SystemMessageContent ||
          nextMessage.sender.uid != message.sender.uid;

      presentationByStableKey[message.stableKey] = (
        showSenderName: showSenderName,
        showAvatar: showAvatar,
      );
    }

    return presentationByStableKey;
  }

  GlobalKey _keyForMessage(ConversationMessageV2 message) {
    return _messageKeys.putIfAbsent(message.stableKey, GlobalKey.new);
  }

  // ============ Build & Build Helpers ============

  List<MessageOverlayActionV2> _overlayActions(ConversationMessageV2 message) {
    final currentUserId = ref.read(authSessionProvider).currentUserId;
    final isOwn = message.sender.uid == currentUserId;
    final composerNotifier = ref.read(
      conversationComposerViewModelProvider(_identity).notifier,
    );
    return <MessageOverlayActionV2>[
      MessageOverlayActionV2(
        label: 'Reply',
        icon: CupertinoIcons.reply,
        onPressed: () {
          _dismissMessageOverlay();
          composerNotifier.beginReply(message);
        },
      ),
      if (_canStartThreadFrom(message))
        MessageOverlayActionV2(
          label: 'Start Thread',
          icon: CupertinoIcons.chat_bubble_2,
          onPressed: () {
            _dismissMessageOverlay();
            widget.onStartThread!(message);
          },
        ),
      if (isOwn && message.content is! AudioMessageContent)
        MessageOverlayActionV2(
          label: 'Edit',
          icon: CupertinoIcons.pencil,
          onPressed: () {
            _dismissMessageOverlay();
            composerNotifier.clearAttachments();
            composerNotifier.beginEdit(message);
          },
        ),
      if (isOwn)
        MessageOverlayActionV2(
          label: 'Delete',
          icon: CupertinoIcons.delete,
          onPressed: () {
            _dismissMessageOverlay();
            _confirmDelete(message);
          },
        ),
    ];
  }

  bool _canStartThreadFrom(ConversationMessageV2 message) {
    return widget.threadRootId == null &&
        widget.onStartThread != null &&
        message.serverMessageId != null &&
        message.threadInfo == null;
  }

  /// Build the actual message list (sliver)
  SliverList _buildMessageSliver(
    List<ConversationMessageV2> messages, {
    Key? key,
    String? highlightedStableKey,
    required Map<String, ({bool showSenderName, bool showAvatar})>
    rowPresentationByStableKey,
  }) {
    final vmNotifier = ref.read(
      conversationTimelineViewModelProvider(_identity).notifier,
    );
    return SliverList.builder(
      key: key,
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final rowPresentation =
            rowPresentationByStableKey[message.stableKey] ??
            const (showSenderName: true, showAvatar: true);
        return KeyedSubtree(
          key: _keyForMessage(message),
          child: MessageRowV2(
            message: message,
            isHighlighted: message.stableKey == highlightedStableKey,
            showSenderName: rowPresentation.showSenderName,
            showAvatar: rowPresentation.showAvatar,
            onLongPress: _openMessageOverlay,
            onReply: () => ref
                .read(conversationComposerViewModelProvider(_identity).notifier)
                .beginReply(message),
            onToggleReaction:
                message.content is StickerMessageContent || message.isDeleted
                ? null
                : (emoji) => unawaited(_toggleReaction(message, emoji)),
            onTapReply: message.replyToMessage != null
                ? () => vmNotifier.jumpToMessageServerId(
                    message.replyToMessage!.id,
                    highlight: true,
                  )
                : null,
            onOpenThread:
                widget.onOpenThread != null &&
                    message.threadInfo != null &&
                    message.threadInfo!.replyCount > 0
                ? () => widget.onOpenThread!(message)
                : null,
            onOpenAttachment: _openAttachment,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationTimelineViewModelProvider(_identity));

    if (state.isBootstrapping) {
      return const Center(child: CupertinoActivityIndicator());
    }

    final placement = state.viewportCommand.placement;

    // If we need to execute a viewport command, schedule it to be executed in the next frame.
    // as well as clear the top preferred anchor measurement.
    if (state.viewportCommandGeneration >
        _lastHandledViewportCommandGeneration) {
      _consumeViewportCommand(state);
    }

    final centerViewportFraction =
        placement == ConversationTimelineViewportPlacement.bottomPreferred
        ? 1.0
        : (_isTopPreferredAnchorResolved ? _topPreferredAnchorAlignment : 0.0);
    final shouldHideUntilMeasured =
        placement == ConversationTimelineViewportPlacement.topPreferred &&
        !_isTopPreferredAnchorResolved;

    final orderedMessages = <ConversationMessageV2>[
      ...state.beforeMessages,
      ...state.afterMessages,
    ];
    _renderedMessagesByStableKey = <String, ConversationMessageV2>{
      for (final message in orderedMessages) message.stableKey: message,
    };
    final rowPresentationByStableKey = _buildRowPresentation(orderedMessages);
    final beforeMessages = state.beforeMessages.reversed.toList(
      growable: false,
    );
    final afterMessages = state.afterMessages;

    _scheduleViewportMeasurement();

    return Stack(
      children: [
        Opacity(
          opacity: shouldHideUntilMeasured ? 0 : 1,
          child: CustomScrollView(
            key: _scrollViewKey,
            center: _centerSliverKey,
            anchor: centerViewportFraction,
            controller: _scrollController,
            slivers: [
              // Fixed top padding?
              const SliverPadding(padding: EdgeInsets.only(top: 8)),

              // Before slice (if not empty)
              if (beforeMessages.isNotEmpty)
                _buildMessageSliver(
                  beforeMessages,
                  highlightedStableKey: state.highlightedStableKey,
                  rowPresentationByStableKey: rowPresentationByStableKey,
                ),

              // Center sentinel / seam
              SliverToBoxAdapter(
                key: _centerSliverKey,
                child: const SizedBox.shrink(),
              ),

              // After slice (if not empty)
              if (afterMessages.isNotEmpty)
                _buildMessageSliver(
                  afterMessages,
                  key: _afterContentSliverKey,
                  highlightedStableKey: state.highlightedStableKey,
                  rowPresentationByStableKey: rowPresentationByStableKey,
                ),
            ],
          ),
        ),
        if (kDebugMode)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Seam @ ${centerViewportFraction.toStringAsFixed(2)}'
                  ' (${placement.name})'
                  ' cmd: ${state.viewportCommand.kind.name} (${state.viewportCommand.placement.name})'
                  ' gen: ${state.viewportCommandGeneration}'
                  ' | before=${state.beforeMessages.length}'
                  ' after=${state.afterMessages.length}'
                  ' | last_visible_id=${_lastVisibleMessageId?.toString() ?? 'null'}',
                ),
              ),
            ),
          ),
        if (state.canLoadNewer || !_latestViewportFacts.isNearBottom)
          Positioned(
            right: _jumpToLatestInset,
            bottom: _jumpToLatestInset,
            child: JumpToLatestFab(
              pendingLiveCount: 0,
              onPressed: () => ref
                  .read(
                    conversationTimelineViewModelProvider(_identity).notifier,
                  )
                  .jumpToLatest(),
            ),
          ),
        if (_activeOverlay case final overlay?)
          MessageOverlayV2(
            details: overlay,
            visible: true,
            actions: _overlayActions(overlay.message),
            quickReactionEmojis: _quickReactionEmojis,
            onDismiss: _dismissMessageOverlay,
            onToggleReaction: (emoji) {
              _dismissMessageOverlay();
              unawaited(_toggleReaction(overlay.message, emoji));
            },
          ),
      ],
    );
  }
}
