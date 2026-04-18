import 'dart:async';

import 'package:chahua/features/chats/conversation/domain/launch_request.dart';
import 'package:chahua/features/chats/conversation_v2/application/timeline_viewport_effect.dart';
import 'package:chahua/features/chats/conversation_v2/application/conversation_timeline_v2_view_model.dart';
import 'package:chahua/features/chats/conversation_v2/application/timeline_viewport_facts.dart';
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
    switch (effect.type) {
      case TimelineViewportEffectType.revealBottom:
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
      data: (state) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              onPressed: () => ref
                  .read(
                    conversationTimelineV2ViewModelProvider(_identity).notifier,
                  )
                  .jumpToLatest(),
              child: const Text('Jump To Latest'),
            ),
          ),
          Expanded(
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: state.messages.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) =>
                  MessageRowV2(message: state.messages[index]),
            ),
          ),
        ],
      ),
    );
  }
}
