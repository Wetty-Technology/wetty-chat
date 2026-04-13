import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/session/dev_session_store.dart';
import '../../../../../core/settings/app_settings_store.dart';
import '../../application/conversation_composer_view_model.dart';
import '../../application/conversation_timeline_view_model.dart';
import '../../domain/conversation_message.dart';
import '../../domain/conversation_scope.dart';
import '../../domain/timeline_entry.dart';
import '../../../models/message_models.dart';
import '../anchored_timeline_view.dart';
import '../message_overlay.dart';
import '../message_row.dart';
import '../system_message_row.dart';
import 'date_separator.dart';
import 'gap_label.dart';
import 'jump_to_latest_fab.dart';
import 'unread_divider.dart';

/// Controller that lets the parent page trigger scrollToLatest on the timeline.
class ConversationTimelineController {
  VoidCallback? _scrollToLatest;

  Future<void> scrollToLatest() async => _scrollToLatest?.call();
}

class ConversationTimeline extends ConsumerStatefulWidget {
  const ConversationTimeline({
    super.key,
    required this.scope,
    required this.timelineArgs,
    this.onOpenThread,
    this.onTapSticker,
    this.onTapMention,
    this.onMessageVisible,
    this.controller,
    this.logTag = 'ConversationTimeline',
  });

  final ConversationScope scope;
  final ConversationTimelineArgs timelineArgs;

  /// Called when the user taps a thread indicator. Chat provides this to
  /// navigate to the thread detail page; thread view leaves it null.
  final void Function(ConversationMessage message)? onOpenThread;

  /// Called when the user taps a sticker bubble to preview sticker details.
  final void Function(ConversationMessage message)? onTapSticker;

  /// Called when the user taps a rendered message mention.
  final void Function(int uid, MentionInfo? mention)? onTapMention;

  /// Extra callback invoked for every visible message during scroll.
  /// Thread uses this to track the max-seen message ID for mark-as-read.
  final void Function(ConversationMessage message)? onMessageVisible;

  /// Optional controller for the parent to trigger scrollToLatest.
  final ConversationTimelineController? controller;

  final String logTag;

  @override
  ConsumerState<ConversationTimeline> createState() =>
      _ConversationTimelineState();
}

class _ConversationTimelineState extends ConsumerState<ConversationTimeline>
    with WidgetsBindingObserver {
  static const double _liveEdgeTolerance = 0.5;
  static const double _timelineEndPadding = 12;
  static const Duration _overlayAnimationDuration = Duration(milliseconds: 150);

  final ScrollController _timelineScrollController = ScrollController();
  final GlobalKey _overlayViewportKey = GlobalKey();
  final Map<String, GlobalKey> _messageRowKeys = <String, GlobalKey>{};

  bool _isAtLiveEdge = true;
  bool _isBootstrapActive = false;
  bool _isUserDragging = false;
  bool _isOverlayVisible = false;
  bool _isVisibleMessageReportScheduled = false;
  int _viewportGeneration = 0;
  Key _timelineViewportKey = const ValueKey<int>(0);
  int? _activeViewportTransactionId;
  String? _lastVisibleMessageReportSignature;
  _ActiveMessageOverlay? _activeOverlay;
  Timer? _overlayDismissTimer;

  static const List<String> _quickReactionEmojis = <String>[
    '👍',
    '❤️',
    '😂',
    '😮',
    '😢',
    '🎉',
  ];

  @override
  void initState() {
    super.initState();
    developer.log(
      'initState: scope=${widget.scope}, '
      'identity=${identityHashCode(this)}',
      name: widget.logTag,
    );
    WidgetsBinding.instance.addObserver(this);
    _timelineScrollController.addListener(_onTimelineScroll);
    widget.controller?._scrollToLatest = _scrollToLatest;
  }

  @override
  void didUpdateWidget(covariant ConversationTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?._scrollToLatest = null;
      widget.controller?._scrollToLatest = _scrollToLatest;
    }
  }

  @override
  void dispose() {
    developer.log(
      'dispose: identity=${identityHashCode(this)}',
      name: widget.logTag,
    );
    WidgetsBinding.instance.removeObserver(this);
    widget.controller?._scrollToLatest = null;
    _timelineScrollController.removeListener(_onTimelineScroll);
    _timelineScrollController.dispose();
    _overlayDismissTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (!_isAtLiveEdge) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref
          .read(
            conversationTimelineViewModelProvider(widget.timelineArgs).notifier,
          )
          .onViewportResized();
    });
  }

  // ---------------------------------------------------------------------------
  // Overlay management
  // ---------------------------------------------------------------------------

  void _openMessageOverlay(MessageLongPressDetails details) {
    if (details.message.isDeleted) {
      return;
    }
    final viewportContext = _overlayViewportKey.currentContext;
    final viewportRenderBox = viewportContext?.findRenderObject() as RenderBox?;
    if (viewportRenderBox == null || !viewportRenderBox.attached) {
      return;
    }
    final bubbleTopLeft = viewportRenderBox.globalToLocal(
      details.bubbleRect.topLeft,
    );
    final bubbleBottomRight = viewportRenderBox.globalToLocal(
      details.bubbleRect.bottomRight,
    );
    final bubbleRect = Rect.fromPoints(bubbleTopLeft, bubbleBottomRight);
    final viewportRect = Offset.zero & viewportRenderBox.size;
    final visibleRect = bubbleRect.intersect(viewportRect);
    if (visibleRect.isEmpty) {
      return;
    }
    FocusScope.of(context).unfocus();
    _overlayDismissTimer?.cancel();
    setState(() {
      _activeOverlay = _ActiveMessageOverlay(
        details.copyWith(bubbleRect: bubbleRect, visibleRect: visibleRect),
      );
      _isOverlayVisible = true;
    });
  }

  void _dismissMessageOverlay() {
    if (_activeOverlay == null) {
      return;
    }
    _overlayDismissTimer?.cancel();
    setState(() {
      _isOverlayVisible = false;
    });
    _overlayDismissTimer = Timer(_overlayAnimationDuration, () {
      if (!mounted) {
        return;
      }
      setState(() {
        if (!_isOverlayVisible) {
          _activeOverlay = null;
        }
      });
    });
  }

  Future<void> _toggleReaction(
    ConversationMessage message,
    String emoji,
  ) async {
    try {
      await ref
          .read(
            conversationTimelineViewModelProvider(widget.timelineArgs).notifier,
          )
          .toggleReaction(message, emoji);
    } catch (error) {
      if (!mounted) {
        return;
      }
      _showErrorDialog('$error');
    }
  }

  List<MessageOverlayAction> _overlayActions(ConversationMessage message) {
    final currentUserId = ref.read(authSessionProvider).currentUserId;
    final isOwn = message.sender.uid == currentUserId;
    final composerNotifier = ref.read(
      conversationComposerViewModelProvider(widget.scope).notifier,
    );

    return <MessageOverlayAction>[
      MessageOverlayAction(
        label: 'Reply',
        icon: CupertinoIcons.reply,
        onPressed: () {
          _dismissMessageOverlay();
          composerNotifier.beginReply(message);
        },
      ),
      if (isOwn && message.messageType != 'audio')
        MessageOverlayAction(
          label: 'Edit',
          icon: CupertinoIcons.pencil,
          onPressed: () {
            _dismissMessageOverlay();
            composerNotifier.clearAttachments();
            composerNotifier.beginEdit(message);
          },
        ),
      if (isOwn)
        MessageOverlayAction(
          label: 'Delete',
          icon: CupertinoIcons.delete,
          isDestructive: true,
          onPressed: () {
            _dismissMessageOverlay();
            _confirmDelete(message);
          },
        ),
    ];
  }

  void _confirmDelete(ConversationMessage message) {
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
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref
                    .read(
                      conversationComposerViewModelProvider(
                        widget.scope,
                      ).notifier,
                    )
                    .delete(message);
              } catch (error) {
                if (mounted) {
                  _showErrorDialog('$error');
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Scroll & edge detection
  // ---------------------------------------------------------------------------

  void _onTimelineScroll() {
    if (!mounted || !_timelineScrollController.hasClients) return;
    final viewState = ref
        .read(conversationTimelineViewModelProvider(widget.timelineArgs))
        .value;
    if (viewState == null) return;

    final isAtLiveEdge = _isAtExactLiveEdge(viewState);
    if (_isAtLiveEdge != isAtLiveEdge) {
      ref
          .read(
            conversationTimelineViewModelProvider(widget.timelineArgs).notifier,
          )
          .onViewportLiveEdgeChanged(isAtLiveEdge);
      setState(() {
        _isAtLiveEdge = isAtLiveEdge;
      });
    }

    _reportVisibleMessages(viewState);
  }

  void _onNearOlderEdge() {
    final viewState = ref
        .read(conversationTimelineViewModelProvider(widget.timelineArgs))
        .value;
    if (viewState == null ||
        !viewState.canLoadOlder ||
        viewState.isLoadingOlder) {
      return;
    }
    final visibleAnchor = _captureTopVisibleAnchor(viewState);
    unawaited(
      ref
          .read(
            conversationTimelineViewModelProvider(widget.timelineArgs).notifier,
          )
          .loadOlder(
            preserveAnchorStableKey: visibleAnchor?.stableKey,
            preserveAnchorDy: visibleAnchor?.dy,
            rebaseAnchorMessageId: visibleAnchor?.messageId,
          ),
    );
  }

  void _onNearNewerEdge() {
    final viewState = ref
        .read(conversationTimelineViewModelProvider(widget.timelineArgs))
        .value;
    if (viewState == null ||
        !viewState.canLoadNewer ||
        viewState.isLoadingNewer) {
      return;
    }
    final visibleAnchor = _captureTopVisibleAnchor(viewState);
    unawaited(
      ref
          .read(
            conversationTimelineViewModelProvider(widget.timelineArgs).notifier,
          )
          .loadNewer(
            preserveAnchorStableKey: visibleAnchor?.stableKey,
            preserveAnchorDy: visibleAnchor?.dy,
            rebaseAnchorMessageId: visibleAnchor?.messageId,
          ),
    );
  }

  /// Report visible messages for read-status tracking.
  void _reportVisibleMessages(ConversationTimelineState viewState) {
    final viewportContext = _overlayViewportKey.currentContext;
    final viewportRenderBox = viewportContext?.findRenderObject() as RenderBox?;
    if (viewportRenderBox == null || !viewportRenderBox.attached) {
      return;
    }
    final viewportRect =
        viewportRenderBox.localToGlobal(Offset.zero) & viewportRenderBox.size;
    final notifier = ref.read(
      conversationTimelineViewModelProvider(widget.timelineArgs).notifier,
    );
    for (final entry in viewState.entries) {
      if (entry is TimelineMessageEntry) {
        final rowContext =
            _messageRowKeys[entry.message.stableKey]?.currentContext;
        final rowRenderBox = rowContext?.findRenderObject() as RenderBox?;
        if (rowRenderBox == null || !rowRenderBox.attached) {
          continue;
        }
        final rowRect =
            rowRenderBox.localToGlobal(Offset.zero) & rowRenderBox.size;
        if (rowRect.intersect(viewportRect).isEmpty) {
          continue;
        }
        notifier.onMessageVisible(entry.message);
        widget.onMessageVisible?.call(entry.message);
      }
    }
  }

  GlobalKey _messageRowKey(String stableKey) =>
      _messageRowKeys.putIfAbsent(stableKey, GlobalKey.new);

  bool _isAtExactLiveEdge(ConversationTimelineState viewState) {
    if (!_timelineScrollController.hasClients || viewState.canLoadNewer) {
      return false;
    }
    final position = _timelineScrollController.position;
    return (position.maxScrollExtent - position.pixels).abs() <=
        _liveEdgeTolerance;
  }

  _VisibleAnchor? _captureTopVisibleAnchor(
    ConversationTimelineState viewState,
  ) {
    final viewportContext = _overlayViewportKey.currentContext;
    final viewportRenderBox = viewportContext?.findRenderObject() as RenderBox?;
    if (viewportRenderBox == null || !viewportRenderBox.attached) {
      return null;
    }
    final viewportRect =
        viewportRenderBox.localToGlobal(Offset.zero) & viewportRenderBox.size;

    _VisibleAnchor? bestAnchor;
    for (final entry in viewState.entries) {
      if (entry is! TimelineMessageEntry) {
        continue;
      }
      final rowContext =
          _messageRowKeys[entry.message.stableKey]?.currentContext;
      final rowRenderBox = rowContext?.findRenderObject() as RenderBox?;
      if (rowRenderBox == null || !rowRenderBox.attached) {
        continue;
      }
      final rowRect =
          rowRenderBox.localToGlobal(Offset.zero) & rowRenderBox.size;
      if (rowRect.intersect(viewportRect).isEmpty) {
        continue;
      }
      final dy = rowRect.top - viewportRect.top;
      if (bestAnchor == null || dy < bestAnchor.dy) {
        bestAnchor = _VisibleAnchor(
          stableKey: entry.message.stableKey,
          messageId: entry.message.serverMessageId,
          dy: dy,
        );
      }
    }
    return bestAnchor;
  }

  void _scheduleVisibleMessageReport(ConversationTimelineState viewState) {
    if (_isVisibleMessageReportScheduled) {
      return;
    }
    final signature =
        '$_timelineViewportKey'
        '|${viewState.entries.length}'
        '|${viewState.anchorEntryIndex}'
        '|${viewState.viewportPlacement}'
        '|${viewState.windowStableKeys.firstOrNull ?? ''}'
        '|${viewState.windowStableKeys.lastOrNull ?? ''}';
    if (_lastVisibleMessageReportSignature == signature) {
      return;
    }
    _isVisibleMessageReportScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isVisibleMessageReportScheduled = false;
      if (!mounted) {
        return;
      }
      final currentState = ref
          .read(conversationTimelineViewModelProvider(widget.timelineArgs))
          .value;
      if (currentState == null) {
        return;
      }
      _lastVisibleMessageReportSignature = signature;
      _reportVisibleMessages(currentState);
    });
  }

  void _pruneMessageRowKeys(ConversationTimelineState viewState) {
    final activeKeys = viewState.entries
        .whereType<TimelineMessageEntry>()
        .map((entry) => entry.message.stableKey)
        .toSet();
    _messageRowKeys.removeWhere(
      (stableKey, _) => !activeKeys.contains(stableKey),
    );
  }

  // ---------------------------------------------------------------------------
  // Navigation helpers
  // ---------------------------------------------------------------------------

  Future<void> _scrollToLatest() async {
    await ref
        .read(
          conversationTimelineViewModelProvider(widget.timelineArgs).notifier,
        )
        .jumpToLatest();
  }

  Future<void> _jumpToMessage(int messageId) async {
    await ref
        .read(
          conversationTimelineViewModelProvider(widget.timelineArgs).notifier,
        )
        .jumpToMessage(messageId);
  }

  void _resetViewportSession(int sessionId) {
    _timelineViewportKey = ValueKey<int>(sessionId);
  }

  void _consumeViewportCommand(int transactionId) {
    _activeViewportTransactionId = null;
    ref
        .read(
          conversationTimelineViewModelProvider(widget.timelineArgs).notifier,
        )
        .consumeViewportCommand(transactionId);
  }

  Future<void> _applyViewportCommand(
    ConversationTimelineState viewState,
    ConversationViewportCommand command,
  ) async {
    if (_activeViewportTransactionId == command.transactionId) {
      return;
    }
    if (_isUserDragging && !command.isBootstrap) {
      return;
    }
    _activeViewportTransactionId = command.transactionId;
    switch (command.type) {
      case ConversationViewportCommandType.showLatest:
      case ConversationViewportCommandType.bootstrapTarget:
        _viewportGeneration += 1;
        setState(() {
          _isBootstrapActive = true;
          _isAtLiveEdge =
              command.type == ConversationViewportCommandType.showLatest &&
              !viewState.canLoadNewer;
          _resetViewportSession(_viewportGeneration);
        });
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await WidgetsBinding.instance.endOfFrame;
          await WidgetsBinding.instance.endOfFrame;
          if (!mounted) {
            return;
          }
          if (command.type == ConversationViewportCommandType.showLatest) {
            _jumpToBottomImmediate();
          }
          setState(() {
            _isBootstrapActive = false;
          });
          _consumeViewportCommand(command.transactionId);
        });
        break;
      case ConversationViewportCommandType.scrollToLoadedTarget:
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) {
            return;
          }
          await _scrollLoadedTargetIntoView(command.messageId);
          if (!mounted) {
            return;
          }
          _consumeViewportCommand(command.transactionId);
        });
        break;
      case ConversationViewportCommandType.preserveOnPrepend:
      case ConversationViewportCommandType.preserveOnAppend:
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          _restorePreservedAnchor(
            anchorStableKey: command.anchorStableKey,
            desiredDy: command.anchorDy,
          );
          _consumeViewportCommand(command.transactionId);
        });
        break;
      case ConversationViewportCommandType.settleAtBottomAfterMutation:
      case ConversationViewportCommandType.settleAtBottomAfterViewportResize:
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _isUserDragging) {
            return;
          }
          _jumpToBottomImmediate();
          _consumeViewportCommand(command.transactionId);
        });
        break;
    }
  }

  Future<void> _scrollLoadedTargetIntoView(int? messageId) async {
    if (messageId == null) {
      return;
    }
    final currentState = ref
        .read(conversationTimelineViewModelProvider(widget.timelineArgs))
        .value;
    if (currentState == null) {
      return;
    }
    TimelineMessageEntry? targetEntry;
    for (final entry
        in currentState.entries.whereType<TimelineMessageEntry>()) {
      if (entry.message.serverMessageId == messageId) {
        targetEntry = entry;
        break;
      }
    }
    final targetContext = targetEntry == null
        ? null
        : _messageRowKeys[targetEntry.message.stableKey]?.currentContext;
    if (targetContext == null) {
      return;
    }
    final viewportContext = _overlayViewportKey.currentContext;
    final viewportRenderBox = viewportContext?.findRenderObject() as RenderBox?;
    final rowRenderBox = targetContext.findRenderObject() as RenderBox?;
    if (viewportRenderBox == null || !viewportRenderBox.attached) {
      return;
    }
    if (rowRenderBox == null || !rowRenderBox.attached) {
      return;
    }
    final viewportRect =
        viewportRenderBox.localToGlobal(Offset.zero) & viewportRenderBox.size;
    final rowRect = rowRenderBox.localToGlobal(Offset.zero) & rowRenderBox.size;
    final travelDistance = (rowRect.top - viewportRect.top).abs();
    final duration = travelDistance > viewportRect.height * 2
        ? Duration.zero
        : const Duration(milliseconds: 250);
    await Scrollable.ensureVisible(
      targetContext,
      alignment: 0,
      duration: duration,
      curve: Curves.easeInOut,
    );
  }

  void _restorePreservedAnchor({
    required String? anchorStableKey,
    required double? desiredDy,
  }) {
    if (anchorStableKey == null ||
        desiredDy == null ||
        !_timelineScrollController.hasClients) {
      return;
    }
    final rowContext = _messageRowKeys[anchorStableKey]?.currentContext;
    final viewportContext = _overlayViewportKey.currentContext;
    final rowRenderBox = rowContext?.findRenderObject() as RenderBox?;
    final viewportRenderBox = viewportContext?.findRenderObject() as RenderBox?;
    if (rowRenderBox == null ||
        !rowRenderBox.attached ||
        viewportRenderBox == null ||
        !viewportRenderBox.attached) {
      return;
    }
    final viewportRect =
        viewportRenderBox.localToGlobal(Offset.zero) & viewportRenderBox.size;
    final rowRect = rowRenderBox.localToGlobal(Offset.zero) & rowRenderBox.size;
    final currentDy = rowRect.top - viewportRect.top;
    final delta = currentDy - desiredDy;
    if (delta.abs() <= _liveEdgeTolerance) {
      return;
    }
    final position = _timelineScrollController.position;
    final targetOffset = (position.pixels + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    _timelineScrollController.jumpTo(targetOffset);
  }

  void _jumpToBottomImmediate() {
    if (!_timelineScrollController.hasClients) {
      return;
    }
    final position = _timelineScrollController.position;
    final bottom = position.maxScrollExtent;
    if ((bottom - position.pixels).abs() <= _liveEdgeTolerance) {
      return;
    }
    _timelineScrollController.jumpTo(bottom);
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

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  bool _shouldShowSenderName(List<TimelineEntry> entries, int index) {
    final entry = entries[index];
    if (entry is! TimelineMessageEntry) {
      return false;
    }
    final message = entry.message;
    if (message.isSystem) {
      return false;
    }
    if (index == 0) {
      return true;
    }
    final previousEntry = entries[index - 1];
    if (previousEntry is! TimelineMessageEntry) {
      return true;
    }
    final previousMessage = previousEntry.message;
    if (previousMessage.isSystem) {
      return true;
    }
    return previousMessage.sender.uid != message.sender.uid;
  }

  bool _shouldShowAvatar(List<TimelineEntry> entries, int index) {
    final entry = entries[index];
    if (entry is! TimelineMessageEntry) {
      return false;
    }
    final message = entry.message;
    if (message.isSystem) {
      return false;
    }
    if (index == entries.length - 1) {
      return true;
    }
    final nextEntry = entries[index + 1];
    if (nextEntry is! TimelineMessageEntry) {
      return true;
    }
    final nextMessage = nextEntry.message;
    if (nextMessage.isSystem) {
      return true;
    }
    return nextMessage.sender.uid != message.sender.uid;
  }

  @override
  Widget build(BuildContext context) {
    final timelineAsync = ref.watch(
      conversationTimelineViewModelProvider(widget.timelineArgs),
    );
    final settings = ref.watch(appSettingsProvider);

    timelineAsync.whenData((state) {
      final viewportCommand = state.viewportCommand;
      developer.log(
        'whenData: viewportCommand=${viewportCommand?.type}, '
        'mode=${state.windowMode}, '
        'placement=${state.viewportPlacement}, '
        'anchorIdx=${state.anchorEntryIndex}/${state.entries.length}, '
        'canLoadNewer=${state.canLoadNewer}, '
        'viewportKey=$_timelineViewportKey, '
        'generation=$_viewportGeneration',
        name: widget.logTag,
      );
      if (viewportCommand != null) {
        unawaited(_applyViewportCommand(state, viewportCommand));
      }
      if (state.infoMessage != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showErrorDialog(state.infoMessage!);
          ref
              .read(
                conversationTimelineViewModelProvider(
                  widget.timelineArgs,
                ).notifier,
              )
              .clearInfoMessage();
        });
      }
    });

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification &&
            notification.dragDetails != null) {
          _isUserDragging = true;
        } else if (notification is ScrollEndNotification) {
          _isUserDragging = false;
          if (mounted) {
            setState(() {});
          }
        } else if (notification is UserScrollNotification &&
            notification.direction == ScrollDirection.idle) {
          _isUserDragging = false;
          if (mounted) {
            setState(() {});
          }
        }
        return false;
      },
      child: Stack(
        key: _overlayViewportKey,
        children: [
          IgnorePointer(
            ignoring: _isBootstrapActive,
            child: AnimatedOpacity(
              opacity: _isBootstrapActive ? 0 : 1,
              duration: const Duration(milliseconds: 80),
              child: timelineAsync.when(
                loading: () =>
                    const Center(child: CupertinoActivityIndicator()),
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('$error', textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        CupertinoButton.filled(
                          onPressed: () => ref.invalidate(
                            conversationTimelineViewModelProvider(
                              widget.timelineArgs,
                            ),
                          ),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (viewState) =>
                    _buildTimeline(viewState, settings.fontSize),
              ),
            ),
          ),
          if (_activeOverlay case final overlay?)
            MessageOverlay(
              details: overlay.details,
              visible: _isOverlayVisible,
              chatMessageFontSize: settings.fontSize,
              actions: _overlayActions(overlay.details.message),
              quickReactionEmojis: _quickReactionEmojis,
              onDismiss: _dismissMessageOverlay,
              onToggleReaction: (emoji) {
                _dismissMessageOverlay();
                unawaited(_toggleReaction(overlay.details.message, emoji));
              },
            ),
          if (timelineAsync.value case final viewState?
              when shouldShowJumpToLatestFab(
                state: viewState,
                isAtLiveEdge: _isAtLiveEdge,
              ))
            Positioned(
              right: 16,
              bottom: 16,
              child: JumpToLatestFab(
                pendingLiveCount: viewState.pendingLiveCount,
                onPressed: _scrollToLatest,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeline(
    ConversationTimelineState viewState,
    double chatMessageFontSize,
  ) {
    if (viewState.entries.isEmpty) {
      return const Center(child: Text('No messages yet'));
    }
    _pruneMessageRowKeys(viewState);
    _scheduleVisibleMessageReport(viewState);
    developer.log(
      '_buildTimeline: key=$_timelineViewportKey, '
      'placement=${viewState.viewportPlacement}, '
      'anchorIdx=${viewState.anchorEntryIndex}/${viewState.entries.length}, '
      'mode=${viewState.windowMode}',
      name: widget.logTag,
    );
    return AnchoredTimelineView(
      key: _timelineViewportKey,
      entries: viewState.entries,
      anchorIndex: viewState.anchorEntryIndex,
      viewportPlacement: viewState.viewportPlacement,
      scrollController: _timelineScrollController,
      onNearOlderEdge: _onNearOlderEdge,
      onNearNewerEdge: _onNearNewerEdge,
      topPadding: 8,
      bottomPadding: _timelineEndPadding,
      entryBuilder: (context, entry, index) {
        final showSenderName = _shouldShowSenderName(viewState.entries, index);
        final showAvatar = _shouldShowAvatar(viewState.entries, index);

        return switch (entry) {
          TimelineMessageEntry(:final message) =>
            message.isSystem
                ? SystemMessageRow(
                    key: _messageRowKey(message.stableKey),
                    message: message,
                  )
                : MessageRow(
                    key: _messageRowKey(message.stableKey),
                    message: message,
                    chatMessageFontSize: chatMessageFontSize,
                    isHighlighted:
                        viewState.highlightedMessageId ==
                        message.serverMessageId,
                    onLongPress: _openMessageOverlay,
                    onReply: () => ref
                        .read(
                          conversationComposerViewModelProvider(
                            widget.scope,
                          ).notifier,
                        )
                        .beginReply(message),
                    onTapSticker: widget.onTapSticker != null
                        ? () => widget.onTapSticker!(message)
                        : null,
                    onTapReply: message.replyToMessage != null
                        ? () => _jumpToMessage(message.replyToMessage!.id)
                        : null,
                    onOpenThread:
                        widget.onOpenThread != null &&
                            message.threadInfo != null &&
                            message.threadInfo!.replyCount > 0
                        ? () => widget.onOpenThread!(message)
                        : null,
                    onToggleReaction: message.messageType == 'sticker'
                        ? null
                        : (emoji) => unawaited(_toggleReaction(message, emoji)),
                    onTapMention: widget.onTapMention,
                    onRetryFailed: message.isFailed
                        ? () => unawaited(_retryFailedMessage(message))
                        : null,
                    showSenderName: showSenderName,
                    showAvatar: showAvatar,
                  ),
          TimelineDateSeparatorEntry(:final day) => DateSeparator(day: day),
          TimelineUnreadMarkerEntry() => const UnreadDivider(),
          TimelineHistoryGapOlderEntry() => const GapLabel(
            text: 'Pull to load older messages',
          ),
          TimelineHistoryGapNewerEntry() => const GapLabel(
            text: 'Scroll down to newer messages',
          ),
          TimelineLoadingOlderEntry() => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CupertinoActivityIndicator()),
          ),
          TimelineLoadingNewerEntry() => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CupertinoActivityIndicator()),
          ),
        };
      },
    );
  }

  Future<void> _retryFailedMessage(ConversationMessage message) async {
    try {
      await ref
          .read(conversationComposerViewModelProvider(widget.scope).notifier)
          .retryFailedMessage(message);
    } catch (error) {
      if (mounted) {
        _showErrorDialog('$error');
      }
    }
  }
}

class _ActiveMessageOverlay {
  const _ActiveMessageOverlay(this.details);
  final MessageLongPressDetails details;
}

class _VisibleAnchor {
  const _VisibleAnchor({
    required this.stableKey,
    required this.messageId,
    required this.dy,
  });

  final String stableKey;
  final int? messageId;
  final double dy;
}
