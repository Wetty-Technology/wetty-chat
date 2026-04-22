import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/features/conversation/timeline/presentation/conversation_timeline_view_model.dart';
import 'package:chahua/features/conversation/shared/domain/conversation_identity.dart';
import 'package:chahua/features/conversation/shared/domain/conversation_message_v2.dart';
import 'package:chahua/features/conversation/shared/domain/launch_request.dart';
import 'package:chahua/features/conversation/compose/presentation/conversation_compose_v2.dart';
import 'package:chahua/features/conversation/timeline/presentation/conversation_timeline_view.dart';

class ConversationSurfaceV2 extends ConsumerStatefulWidget {
  const ConversationSurfaceV2({
    super.key,
    required this.identity,
    required this.launchRequest,
    this.onOpenThread,
  });

  final ConversationIdentity identity;
  final LaunchRequest launchRequest;
  final void Function(ConversationMessageV2 message)? onOpenThread;

  @override
  ConsumerState<ConversationSurfaceV2> createState() =>
      _ConversationSurfaceV2State();
}

class _ConversationSurfaceV2State extends ConsumerState<ConversationSurfaceV2> {
  final GlobalKey<ConversationComposeV2State> _composeKey =
      GlobalKey<ConversationComposeV2State>();

  Future<void> _handleMessageSent() async {
    ref
        .read(conversationTimelineViewModelProvider(widget.identity).notifier)
        .followLatestTailIfNeeded();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        _composeKey.currentState?.dismissTransientUi();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Container(
              color: colors.chatBackground,
              child: ConversationTimelineView(
                chatId: widget.identity.chatId,
                threadRootId: widget.identity.threadRootId,
                launchRequest: widget.launchRequest,
                onOpenThread: widget.onOpenThread,
              ),
            ),
          ),
          ConversationComposeV2(
            key: _composeKey,
            identity: widget.identity,
            onMessageSent: _handleMessageSent,
          ),
        ],
      ),
    );
  }
}
