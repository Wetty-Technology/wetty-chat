import 'package:chahua/features/chats/conversation/domain/launch_request.dart';
import 'package:chahua/features/chats/conversation_v2/application/conversation_timeline_v2_view_model.dart';
import 'package:chahua/features/chats/conversation_v2/application/timeline_viewport_facts.dart';
import 'package:chahua/features/chats/conversation_v2/domain/conversation_message_v2.dart';
import 'package:chahua/features/chats/conversation_v2/presentation/message_bubble/message_row_v2.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  ConversationTimelineV2Identity get _identity =>
      (chatId: widget.chatId, threadRootId: widget.threadRootId);

  @override
  void initState() {
    super.initState();
    _scrollController = _buildScrollController();
    _scheduleInitializeLaunchRequest();
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
    switch (state.viewportCommandKind) {
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

    if (state.isBootstrapping) {
      return const Center(child: CupertinoActivityIndicator());
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumeViewportCommand(state);
    });
    final allMessages = _flattenMessages(state);
    final beforeMessages = state.beforeMessages.reversed.toList(
      growable: false,
    );
    final afterMessages = state.afterMessages;
    final centerViewportFraction = state.centerViewportFraction;

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
                  .jumpToMessage('client:missing-message'),
              child: const Text('missing'),
            ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              onPressed: () => ref
                  .read(
                    conversationTimelineV2ViewModelProvider(_identity).notifier,
                  )
                  .jumpToMessage(allMessages[10].stableKey),
              child: const Text('#10'),
            ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              onPressed: () => ref
                  .read(
                    conversationTimelineV2ViewModelProvider(_identity).notifier,
                  )
                  .jumpToUnread(25),
              child: const Text('unread 25'),
            ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              onPressed: () => ref
                  .read(
                    conversationTimelineV2ViewModelProvider(_identity).notifier,
                  )
                  .jumpToLatest(),
              child: const Text('Jump To Latest'),
            ),
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              onPressed: () => ref
                  .read(
                    conversationTimelineV2ViewModelProvider(_identity).notifier,
                  )
                  .addMessage(),
              child: const Text('Add Message'),
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
            ' | before=${state.beforeMessages.length}'
            ' after=${state.afterMessages.length}',
          ),
        ),
        Expanded(
          child: KeyedSubtree(
            key: _scrollViewportKey,
            child: CustomScrollView(
              center: _centerSliverKey,
              anchor: centerViewportFraction,
              controller: _scrollController,
              slivers: [
                const SliverPadding(padding: EdgeInsets.only(top: 8)),
                if (beforeMessages.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: _buildMessageSliver(beforeMessages),
                  ),
                SliverPadding(
                  key: _centerSliverKey,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: const SliverToBoxAdapter(child: SizedBox.shrink()),
                ),
                if (afterMessages.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: _buildMessageSliver(
                      afterMessages,
                      highlightedStableKey: state.highlightedStableKey,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  SliverList _buildMessageSliver(
    List<ConversationMessageV2> messages, {
    String? highlightedStableKey,
  }) {
    return SliverList.builder(
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return KeyedSubtree(
          key: _keyForMessage(message),
          child: MessageRowV2(
            message: message,
            isHighlighted: message.stableKey == highlightedStableKey,
          ),
        );
      },
    );
  }

  GlobalKey _keyForMessage(ConversationMessageV2 message) {
    return _messageKeys.putIfAbsent(message.stableKey, GlobalKey.new);
  }

  List<ConversationMessageV2> _flattenMessages(
    ConversationTimelineV2State state,
  ) {
    return <ConversationMessageV2>[
      ...state.beforeMessages,
      ...state.afterMessages,
    ];
  }
}
