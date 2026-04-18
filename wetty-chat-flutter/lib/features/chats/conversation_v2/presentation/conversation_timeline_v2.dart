import 'package:chahua/features/chats/conversation/domain/launch_request.dart';
import 'package:chahua/features/chats/conversation_v2/application/conversation_timeline_v2_view_model.dart';
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
  late final ScrollController _scrollController;

  ConversationTimelineV2Identity get _identity =>
      (chatId: widget.chatId, threadRootId: widget.threadRootId);

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _initializeLaunchRequest();
  }

  @override
  void didUpdateWidget(covariant ConversationTimelineV2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.launchRequest != widget.launchRequest) {
      _initializeLaunchRequest();
    }
  }

  void _initializeLaunchRequest() {
    ref
        .read(conversationTimelineV2ViewModelProvider(_identity).notifier)
        .initialize(widget.launchRequest);
  }

  @override
  void dispose() {
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
