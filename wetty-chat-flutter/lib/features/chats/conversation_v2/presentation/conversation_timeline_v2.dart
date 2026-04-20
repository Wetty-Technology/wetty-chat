import 'package:chahua/features/chats/conversation/domain/launch_request.dart';
import 'package:chahua/features/chats/conversation_v2/application/conversation_timeline_v2_state.dart';
import 'package:chahua/features/chats/conversation_v2/application/conversation_timeline_v2_view_model.dart';
import 'package:chahua/features/chats/conversation_v2/application/timeline_viewport_facts.dart';
import 'package:chahua/features/chats/conversation_v2/domain/conversation_message_v2.dart';
import 'package:chahua/features/chats/conversation_v2/domain/conversation_timeline_v2_identity.dart';
import 'package:chahua/features/chats/conversation_v2/presentation/message_bubble/message_row_v2.dart';
import 'package:chahua/core/settings/app_settings_store.dart';
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

class ConversationTimelineV2 extends ConsumerStatefulWidget {
  const ConversationTimelineV2({
    super.key,
    required this.chatId,
    required this.launchRequest,
    this.threadRootId,
  });

  final String chatId;
  final String? threadRootId;
  final LaunchRequest launchRequest;

  @override
  ConsumerState<ConversationTimelineV2> createState() =>
      _ConversationTimelineV2State();
}

class _ConversationTimelineV2State
    extends ConsumerState<ConversationTimelineV2> {
  static const double _edgeThreshold = 80;

  late ScrollController _scrollController;
  int _lastHandledViewportCommandGeneration = 0;
  final GlobalKey _centerSliverKey = GlobalKey();
  final GlobalKey _scrollViewportKey = GlobalKey();
  final Map<String, GlobalKey> _messageKeys = <String, GlobalKey>{};
  bool _isMeasureScheduled = false;
  double _topPreferredAnchorAlignment = 0;
  bool _isTopPreferredAnchorResolved = false;
  int _lastMeasuredTopPreferredGeneration = 0;

  ConversationTimelineV2Identity get _identity =>
      (chatId: widget.chatId, threadRootId: widget.threadRootId);

  @override
  void initState() {
    super.initState();
    _scrollController = _buildScrollController();
    debugPrint(
      'initState: identity=$_identity, launchRequest=${widget.launchRequest}',
    );
    _scheduleInitializeLaunchRequest();
  }

  void _scheduleTopPreferredMeasurement() {
    if (_isMeasureScheduled) {
      return;
    }
    _isMeasureScheduled = true;
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
  void didUpdateWidget(covariant ConversationTimelineV2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chatId != widget.chatId ||
        oldWidget.threadRootId != widget.threadRootId) {
      _lastHandledViewportCommandGeneration = 0;
    }
    if (oldWidget.launchRequest != widget.launchRequest) {
      _scheduleInitializeLaunchRequest();
    }
  }

  ScrollController _buildScrollController({double initialScrollOffset = 0}) {
    final controller = ScrollController(
      initialScrollOffset: initialScrollOffset,
    );
    controller.addListener(_reportViewportFacts);
    return controller;
  }

  void _scheduleInitializeLaunchRequest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      ref
          .read(conversationTimelineV2ViewModelProvider(_identity).notifier)
          .initialize(widget.launchRequest);
    });
  }

  /// Reports the viewport facts to the view model.
  void _reportViewportFacts() {
    if (!_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;
    final facts = TimelineViewportFacts(
      isNearTop: (position.pixels - position.minScrollExtent) <= _edgeThreshold,
      isNearBottom:
          (position.maxScrollExtent - position.pixels) <= _edgeThreshold,
    );
    ref
        .read(conversationTimelineV2ViewModelProvider(_identity).notifier)
        .onViewportChanged(facts);
  }

  void _consumeViewportCommand(ConversationTimelineV2State state) {
    final generation = state.viewportCommandGeneration;
    if (generation <= _lastHandledViewportCommandGeneration) {
      return;
    }

    _lastHandledViewportCommandGeneration = generation;
    switch (state.viewportCommand.kind) {
      case ConversationTimelineV2ViewportCommandKind.none:
        return;
      case ConversationTimelineV2ViewportCommandKind.resetToCenterOrigin:
        _resetToCenterOrigin();
        break;
      case ConversationTimelineV2ViewportCommandKind.scrollToBottom:
        _scrollToBottom();
        break;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reportViewportFacts();
    });
  }

  Future<void> _resetToCenterOrigin() async {
    if (!mounted || !_scrollController.hasClients) {
      return;
    }

    const animateThreshold = 1200.0;
    final currentOffset = _scrollController.position.pixels;
    final targetOffset = 0.0;
    final distance = (currentOffset - targetOffset).abs();

    if (distance <= animateThreshold) {
      await _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    _scrollController.jumpTo(targetOffset);
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

  @override
  void dispose() {
    _scrollController.removeListener(_reportViewportFacts);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(conversationTimelineV2ViewModelProvider(_identity));
    final settings = ref.watch(appSettingsProvider);

    if (state.isBootstrapping) {
      return const Center(child: CupertinoActivityIndicator());
    }

    final placement = state.viewportCommand.placement;

    // If we need to execute a viewport command, schedule it to be executed in the next frame.
    // as well as clear the top preferred anchor measurement.
    if (state.viewportCommandGeneration >
        _lastHandledViewportCommandGeneration) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _consumeViewportCommand(state);
      });

      if (placement == ConversationTimelineV2ViewportPlacement.topPreferred) {
        _scheduleTopPreferredMeasurement();
      }
      _isTopPreferredAnchorResolved = false;
    }

    final centerViewportFraction =
        placement == ConversationTimelineV2ViewportPlacement.bottomPreferred
        ? 1.0
        : _topPreferredAnchorAlignment;
    final shouldHideUntilMeasured =
        placement == ConversationTimelineV2ViewportPlacement.topPreferred &&
        !_isTopPreferredAnchorResolved;

    final beforeMessages = state.beforeMessages.reversed.toList(
      growable: false,
    );
    final afterMessages = state.afterMessages;

    // Actually build the main content
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 0,
          children: [
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              onPressed: () => ref
                  .read(
                    conversationTimelineV2ViewModelProvider(_identity).notifier,
                  )
                  .jumpToLatest(),
              child: const Text('Jump To Latest'),
            ),
          ],
        ),
        if (state.isResolvingJump)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Resolving jump target...'),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Seam @ ${centerViewportFraction.toStringAsFixed(2)}'
            ' (${placement.name})'
            ' gen: ${state.viewportCommandGeneration}'
            ' | before=${state.beforeMessages.length}'
            ' after=${state.afterMessages.length}',
          ),
        ),
        Expanded(
          child: KeyedSubtree(
            key: _scrollViewportKey,
            child: Opacity(
              opacity: shouldHideUntilMeasured ? 0 : 1,
              child: CustomScrollView(
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
          ),
        ),
      ],
    );
  }

  SliverList _buildMessageSliver(
    List<ConversationMessageV2> messages, {
    Key? key,
    required double chatMessageFontSize,
    String? highlightedStableKey,
  }) {
    final vmNotifier = ref.read(
      conversationTimelineV2ViewModelProvider(_identity).notifier,
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
            onTapReply: message.replyToMessage != null
                ? () => vmNotifier.jumpToMessageServerId(
                    message.replyToMessage!.id,
                    highlight: true,
                  )
                : null,
            onOpenThread:
                message.threadInfo != null && message.threadInfo!.replyCount > 0
                ? () {
                    debugPrint(
                      'onOpenThread: ${message.threadInfo?.replyCount}',
                    );
                  }
                : null,
          ),
        );
      },
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
}
