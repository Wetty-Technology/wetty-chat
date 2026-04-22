import 'dart:async';
import 'dart:developer';

import 'package:chahua/features/conversation/compose/presentation/conversation_composer_view_model.dart';
import 'package:chahua/features/conversation/timeline/presentation/conversation_timeline_view_model.dart';
import 'package:chahua/features/conversation/shared/domain/conversation_message_v2.dart';
import 'package:chahua/features/conversation/shared/domain/conversation_identity.dart';
import 'package:chahua/features/conversation/shared/domain/launch_request.dart';
import 'package:chahua/features/conversation/timeline/presentation/message_long_press_details_v2.dart';
import 'package:chahua/features/conversation/timeline/presentation/message_overlay_v2.dart';
import 'package:chahua/features/conversation/message_bubble/presentation/message_row_v2.dart';
import 'package:chahua/core/session/dev_session_store.dart';
import 'package:chahua/core/settings/app_settings_store.dart';
import 'package:chahua/features/conversation/timeline/presentation/parts/jump_to_latest_fab.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

class ConversationTimelineView extends ConsumerStatefulWidget {
  const ConversationTimelineView({
    super.key,
    required this.chatId,
    required this.launchRequest,
    this.threadRootId,
    this.onOpenThread,
  });

  final int chatId;
  final int? threadRootId;
  final LaunchRequest launchRequest;
  final void Function(ConversationMessageV2 message)? onOpenThread;

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
  final Map<String, GlobalKey> _messageKeys = <String, GlobalKey>{};
  bool _isMeasureScheduled = false;
  double _topPreferredAnchorAlignment = 0;
  bool _isTopPreferredAnchorResolved = false;
  UniqueKey _scrollViewKey = UniqueKey();
  MessageLongPressDetailsV2? _activeOverlay;
  TimelineViewportFacts _latestViewportFacts = const TimelineViewportFacts();

  ConversationIdentity get _identity =>
      (chatId: widget.chatId, threadRootId: widget.threadRootId);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_updateViewportFacts);
    _scheduleInitializeLaunchRequest();
  }

  void _scheduleTopPreferredMeasurement() {
    if (_isMeasureScheduled) {
      return;
    }
    _isMeasureScheduled = true;

    _isTopPreferredAnchorResolved = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isMeasureScheduled = false;
      if (!mounted) {
        return;
      }

      final renderObject = _centerSliverKey.currentContext?.findRenderObject();
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
          _scheduleTopPreferredMeasurement();
        }
        break;
      case ConversationTimelineViewportCommandKind.scrollToBottom:
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
        break;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateViewportFacts();
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
    final bubbleRect = details.bubbleRect;
    final viewportSize = context.size;
    if (viewportSize == null) {
      return;
    }
    final viewportRect = Offset.zero & viewportSize;
    final visibleRect = bubbleRect.intersect(viewportRect);
    if (visibleRect.isEmpty) {
      return;
    }
    setState(() {
      _activeOverlay = details.copyWith(
        bubbleRect: bubbleRect,
        visibleRect: visibleRect,
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

  bool _shouldShowSenderName(List<ConversationMessageV2> messages, int index) {
    final message = messages[index];
    if (message.content is SystemMessageContent) {
      return false;
    }
    if (index == 0) {
      return true;
    }
    final previousMessage = messages[index - 1];
    if (previousMessage.content is SystemMessageContent) {
      return true;
    }
    return previousMessage.sender.uid != message.sender.uid;
  }

  bool _shouldShowAvatar(List<ConversationMessageV2> messages, int index) {
    final message = messages[index];
    if (message.content is SystemMessageContent) {
      return false;
    }
    if (index == messages.length - 1) {
      return true;
    }
    final nextMessage = messages[index + 1];
    if (nextMessage.content is SystemMessageContent) {
      return true;
    }
    return nextMessage.sender.uid != message.sender.uid;
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

  SliverList _buildMessageSliver(
    List<ConversationMessageV2> messages, {
    Key? key,
    required double chatMessageFontSize,
    String? highlightedStableKey,
  }) {
    final vmNotifier = ref.read(
      conversationTimelineViewModelProvider(_identity).notifier,
    );
    return SliverList.builder(
      key: key,
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final showSenderName = _shouldShowSenderName(messages, index);
        final showAvatar = _shouldShowAvatar(messages, index);
        return KeyedSubtree(
          key: _keyForMessage(message),
          child: MessageRowV2(
            message: message,
            chatMessageFontSize: chatMessageFontSize,
            isHighlighted: message.stableKey == highlightedStableKey,
            showSenderName: showSenderName,
            showAvatar: showAvatar,
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
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationTimelineViewModelProvider(_identity));
    final settings = ref.watch(appSettingsProvider);

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

    final beforeMessages = state.beforeMessages.reversed.toList(
      growable: false,
    );
    final afterMessages = state.afterMessages;

    _updateViewportFacts();

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
              const SliverPadding(padding: EdgeInsets.only(top: 8)),
              if (beforeMessages.isNotEmpty)
                _buildMessageSliver(
                  beforeMessages,
                  chatMessageFontSize: settings.fontSize,
                ),
              if (afterMessages.isNotEmpty)
                _buildMessageSliver(
                  afterMessages,
                  key: _centerSliverKey,
                  chatMessageFontSize: settings.fontSize,
                  highlightedStableKey: state.highlightedStableKey,
                )
              else
                SliverToBoxAdapter(
                  key: _centerSliverKey,
                  child: const SizedBox.shrink(),
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
                  ' after=${state.afterMessages.length}',
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

  @override
  void dispose() {
    _scrollController.removeListener(_updateViewportFacts);
    _scrollController.dispose();
    super.dispose();
  }
}
