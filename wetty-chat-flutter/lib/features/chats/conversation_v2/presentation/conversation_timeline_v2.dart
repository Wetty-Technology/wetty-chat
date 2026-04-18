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

  late final ScrollController _scrollController;
  StreamSubscription<TimelineViewportEffect>? _effectSubscription;
  final Map<String, GlobalKey> _messageKeys = <String, GlobalKey>{};
  bool _lastIsNearTop = true;
  bool _lastIsNearBottom = false;

  ConversationTimelineV2Identity get _identity =>
      (chatId: widget.chatId, threadRootId: widget.threadRootId);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_handleScroll);
    _initializeLaunchRequest();
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
      _initializeLaunchRequest();
    }
  }

  void _initializeLaunchRequest() {
    ref
        .read(conversationTimelineV2ViewModelProvider(_identity).notifier)
        .initialize(widget.launchRequest);
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
      isNearTop: position.pixels <= _edgeThreshold,
      isNearBottom:
          (position.maxScrollExtent - position.pixels) <= _edgeThreshold,
      pixels: position.pixels,
      maxScrollExtent: position.maxScrollExtent,
    );

    if (facts.isNearTop == _lastIsNearTop &&
        facts.isNearBottom == _lastIsNearBottom) {
      return;
    }

    _lastIsNearTop = facts.isNearTop;
    _lastIsNearBottom = facts.isNearBottom;
    ref
        .read(conversationTimelineV2ViewModelProvider(_identity).notifier)
        .onViewportChanged(facts);

    debugPrint(
      'ConversationTimelineV2 scroll: '
      'isNearTop=${facts.isNearTop} '
      'isNearBottom=${facts.isNearBottom} '
      'pixels=${facts.pixels.toStringAsFixed(1)} '
      'maxScrollExtent=${facts.maxScrollExtent.toStringAsFixed(1)}',
    );
  }

  Future<void> _handleViewportEffect(TimelineViewportEffect effect) async {
    if (effect.isBottomTarget) {
      await _scrollToBottom();
      return;
    }

    await _scrollToMessage(effect);
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

  Future<void> _scrollToMessage(TimelineViewportEffect effect) async {
    final target = effect.target;
    if (target == null) {
      return;
    }

    final targetKey = _messageKeys[target];
    final targetContext = targetKey?.currentContext;
    if (targetContext == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _handleViewportEffect(effect);
        }
      });
      return;
    }

    await Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: switch (effect.alignment) {
        TimelineViewportAlignment.top => 0,
        TimelineViewportAlignment.center => 0.5,
        TimelineViewportAlignment.bottom => 1,
      },
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
        final anchorIndex = state.anchorStableKey == null
            ? -1
            : state.messages.indexWhere(
                (message) => message.stableKey == state.anchorStableKey,
              );
        final hasAnchor = anchorIndex >= 0;
        final beforeMessages = hasAnchor
            ? state.messages.take(anchorIndex).toList(growable: false)
            : state.messages;
        final anchorMessage = hasAnchor ? state.messages[anchorIndex] : null;
        final afterMessages = hasAnchor
            ? state.messages.skip(anchorIndex + 1).toList(growable: false)
            : const <ConversationMessageV2>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
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
                  child: const Text('Jump Missing'),
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
                      .jumpToMessage(state.messages[20].stableKey),
                  child: const Text('Jump To Message'),
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
            if (anchorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('Anchor: ${anchorMessage.stableKey}'),
              ),
            Expanded(
              child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  const SliverPadding(padding: EdgeInsets.only(top: 8)),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: _buildMessageSliver(beforeMessages),
                  ),
                  if (anchorMessage != null)
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: afterMessages.isEmpty ? 0 : 12,
                          ),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: CupertinoColors.activeBlue,
                                width: 1.5,
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: KeyedSubtree(
                                key: _keyForMessage(anchorMessage),
                                child: MessageRowV2(message: anchorMessage),
                              ),
                            ),
                          ),
                        ),
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
          ],
        );
      },
    );
  }

  SliverList _buildMessageSliver(List<ConversationMessageV2> messages) {
    return SliverList.builder(
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return Padding(
          padding: EdgeInsets.only(
            bottom: index == messages.length - 1 ? 0 : 12,
          ),
          child: KeyedSubtree(
            key: _keyForMessage(message),
            child: MessageRowV2(message: message),
          ),
        );
      },
    );
  }

  GlobalKey _keyForMessage(ConversationMessageV2 message) {
    return _messageKeys.putIfAbsent(message.stableKey, GlobalKey.new);
  }
}
