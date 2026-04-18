import 'dart:async';
import 'package:chahua/features/chats/conversation/domain/launch_request.dart';
import 'package:chahua/features/chats/conversation_v2/application/timeline_viewport_effect.dart';
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
  StreamSubscription<TimelineViewportEffect>? _effectSubscription;
  final GlobalKey _centerSliverKey = GlobalKey();
  final GlobalKey _scrollViewportKey = GlobalKey();
  final Map<String, GlobalKey> _messageKeys = <String, GlobalKey>{};

  ConversationTimelineV2Identity get _identity =>
      (chatId: widget.chatId, threadRootId: widget.threadRootId);

  @override
  void initState() {
    super.initState();
    _scrollController = _buildScrollController();
    // _scheduleInitializeLaunchRequest();
    _subscribeToEffects();
  }

  @override
  void didUpdateWidget(covariant ConversationTimelineV2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chatId != widget.chatId ||
        oldWidget.threadRootId != widget.threadRootId) {
      _subscribeToEffects();
    }
    if (oldWidget.launchRequest != widget.launchRequest) {
      _scheduleInitializeLaunchRequest();
    }
  }

  ScrollController _buildScrollController({double initialScrollOffset = 0}) {
    final controller = ScrollController(
      initialScrollOffset: initialScrollOffset,
    );
    controller.addListener(_handleScroll);
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

  void _subscribeToEffects() {
    _effectSubscription?.cancel();
    _effectSubscription = ref
        .read(conversationTimelineV2ViewModelProvider(_identity).notifier)
        .effects
        .listen(_handleViewportEffect);
  }

  void _handleScroll() {
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

  Future<void> _handleViewportEffect(TimelineViewportEffect effect) async {
    if (effect.isBottomTarget) {
      await _scrollToBottom();
    }
  }

  Future<void> _scrollToBottom() async {
    if (!_scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollToBottom();
        }
      });
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
    _effectSubscription?.cancel();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(
      conversationTimelineV2ViewModelProvider(_identity),
    );

    return stateAsync.when(
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (error, _) => Center(child: Text('error: $error')),
      data: (state) {
        final allMessages = _flattenMessages(state);
        final beforeMessages = state.beforeMessages.reversed.toList(
          growable: false,
        );
        final centerMessages = state.centerMessages;
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  onPressed: () => ref
                      .read(
                        conversationTimelineV2ViewModelProvider(
                          _identity,
                        ).notifier,
                      )
                      .jumpToMessage('client:missing-message'),
                  child: const Text('missing'),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  onPressed: () => ref
                      .read(
                        conversationTimelineV2ViewModelProvider(
                          _identity,
                        ).notifier,
                      )
                      .jumpToMessage(allMessages[10].stableKey),
                  child: const Text('#10'),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  onPressed: () => ref
                      .read(
                        conversationTimelineV2ViewModelProvider(
                          _identity,
                        ).notifier,
                      )
                      .jumpToUnread(25),
                  child: const Text('unread 25'),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  onPressed: () => ref
                      .read(
                        conversationTimelineV2ViewModelProvider(
                          _identity,
                        ).notifier,
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
            if (centerMessages.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Mode: ${state.mode.name} | Center: ${centerMessages.first.stableKey}'
                  ' @ ${centerViewportFraction.toStringAsFixed(2)}',
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
                      sliver: _buildMessageSliver(
                        centerMessages,
                        highlightedStableKey: state.highlightedStableKey,
                      ),
                    ),
                    if (afterMessages.isNotEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        sliver: _buildMessageSliver(afterMessages),
                      ),
                    const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
                  ],
                ),
              ),
            ),
          ],
        );
      },
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
        final isHighlighted = message.stableKey == highlightedStableKey;
        return Padding(
          padding: EdgeInsets.only(
            bottom: index == messages.length - 1 ? 0 : 12,
          ),
          child: DecoratedBox(
            decoration: isHighlighted
                ? BoxDecoration(
                    border: Border.all(
                      color: CupertinoColors.activeBlue,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  )
                : const BoxDecoration(),
            child: Padding(
              padding: isHighlighted
                  ? const EdgeInsets.all(2)
                  : EdgeInsets.zero,
              child: KeyedSubtree(
                key: _keyForMessage(message),
                child: MessageRowV2(message: message),
              ),
            ),
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
      ...state.centerMessages,
      ...state.afterMessages,
    ];
  }
}
