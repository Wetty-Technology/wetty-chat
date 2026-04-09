import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/session/dev_session_store.dart';
import '../../../../../core/settings/app_settings_store.dart';
import '../../application/conversation_composer_view_model.dart';
import '../../application/conversation_timeline_view_model.dart';
import '../../domain/conversation_message.dart';
import '../../domain/conversation_scope.dart';
import '../../domain/timeline_entry.dart';
import '../../domain/viewport_placement.dart';
import '../anchored_timeline_view.dart';
import '../message_overlay.dart';
import '../message_row.dart';
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
    this.onMessageVisible,
    this.controller,
    this.logTag = 'ConversationTimeline',
  });

  final ConversationScope scope;
  final ConversationTimelineArgs timelineArgs;

  /// Called when the user taps a thread indicator. Chat provides this to
  /// navigate to the thread detail page; thread view leaves it null.
  final void Function(ConversationMessage message)? onOpenThread;

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

class _ConversationTimelineState extends ConsumerState<ConversationTimeline> {
  static const double _liveEdgeScrollThreshold = 50;
  static const double _timelineEndPadding = 12;
  static const Duration _overlayAnimationDuration = Duration(milliseconds: 150);

  final ScrollController _timelineScrollController = ScrollController();
  final GlobalKey _overlayViewportKey = GlobalKey();

  bool _isAtLiveEdge = true;
  bool _isOverlayVisible = false;
  int _viewportGeneration = 0;
  Key _timelineViewportKey = const ValueKey<int>(0);
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
    widget.controller?._scrollToLatest = null;
    _timelineScrollController.removeListener(_onTimelineScroll);
    _timelineScrollController.dispose();
    _overlayDismissTimer?.cancel();
    super.dispose();
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
        .valueOrNull;
    if (viewState == null) return;

    final position = _timelineScrollController.position;
    final isAtLiveEdge =
        !viewState.canLoadNewer &&
        (position.maxScrollExtent - position.pixels) < _liveEdgeScrollThreshold;
    if (_isAtLiveEdge != isAtLiveEdge) {
      setState(() {
        _isAtLiveEdge = isAtLiveEdge;
      });
    }

    _reportVisibleMessages(viewState);
  }

  void _onNearOlderEdge() {
    final viewState = ref
        .read(conversationTimelineViewModelProvider(widget.timelineArgs))
        .valueOrNull;
    if (viewState == null ||
        !viewState.canLoadOlder ||
        viewState.isLoadingOlder) {
      return;
    }
    unawaited(
      ref
          .read(
            conversationTimelineViewModelProvider(widget.timelineArgs).notifier,
          )
          .loadOlder(),
    );
  }

  void _onNearNewerEdge() {
    final viewState = ref
        .read(conversationTimelineViewModelProvider(widget.timelineArgs))
        .valueOrNull;
    if (viewState == null ||
        !viewState.canLoadNewer ||
        viewState.isLoadingNewer) {
      return;
    }
    unawaited(
      ref
          .read(
            conversationTimelineViewModelProvider(widget.timelineArgs).notifier,
          )
          .loadNewer(),
    );
  }

  /// Report visible messages for read-status tracking.
  void _reportVisibleMessages(ConversationTimelineState viewState) {
    final notifier = ref.read(
      conversationTimelineViewModelProvider(widget.timelineArgs).notifier,
    );
    for (final entry in viewState.entries) {
      if (entry is TimelineMessageEntry) {
        notifier.onMessageVisible(entry.message);
        widget.onMessageVisible?.call(entry.message);
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final timelineAsync = ref.watch(
      conversationTimelineViewModelProvider(widget.timelineArgs),
    );
    final settings = ref.watch(appSettingsProvider);

    timelineAsync.whenData((state) {
      final locatePlan = state.locatePlan;
      developer.log(
        'whenData: locatePlan=${locatePlan?.placement}, '
        'mode=${state.windowMode}, '
        'placement=${state.viewportPlacement}, '
        'anchorIdx=${state.anchorEntryIndex}/${state.entries.length}, '
        'canLoadNewer=${state.canLoadNewer}, '
        'viewportKey=$_timelineViewportKey, '
        'generation=$_viewportGeneration',
        name: widget.logTag,
      );
      if (locatePlan != null) {
        _viewportGeneration += 1;
        _isAtLiveEdge =
            state.viewportPlacement == ConversationViewportPlacement.liveEdge &&
            !state.canLoadNewer;
        _resetViewportSession(_viewportGeneration);
        developer.log(
          'applied locatePlan: placement=${locatePlan.placement}, '
          'resolvedPlacement=${state.viewportPlacement}, '
          'isAtLiveEdge=$_isAtLiveEdge, '
          'newKey=$_timelineViewportKey, '
          'newGeneration=$_viewportGeneration',
          name: widget.logTag,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref
              .read(
                conversationTimelineViewModelProvider(
                  widget.timelineArgs,
                ).notifier,
              )
              .consumeLocatePlan();
        });
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

    return Stack(
      key: _overlayViewportKey,
      children: [
        timelineAsync.when(
          loading: () => const Center(child: CupertinoActivityIndicator()),
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
          data: (viewState) => _buildTimeline(viewState, settings.fontSize),
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
        if (timelineAsync.valueOrNull case final viewState?
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
    );
  }

  Widget _buildTimeline(
    ConversationTimelineState viewState,
    double chatMessageFontSize,
  ) {
    if (viewState.entries.isEmpty) {
      return const Center(child: Text('No messages yet'));
    }
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
        return switch (entry) {
          TimelineMessageEntry(:final message) => MessageRow(
            key: ValueKey(message.stableKey),
            message: message,
            chatMessageFontSize: chatMessageFontSize,
            isHighlighted:
                viewState.highlightedMessageId == message.serverMessageId,
            onLongPress: _openMessageOverlay,
            onReply: () => ref
                .read(
                  conversationComposerViewModelProvider(widget.scope).notifier,
                )
                .beginReply(message),
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
}

class _ActiveMessageOverlay {
  const _ActiveMessageOverlay(this.details);
  final MessageLongPressDetails details;
}
