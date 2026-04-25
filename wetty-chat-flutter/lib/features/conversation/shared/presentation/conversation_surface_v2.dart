import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/features/shared/application/app_refresh_coordinator.dart';
import 'package:chahua/features/conversation/timeline/presentation/conversation_timeline_view_model.dart';
import 'package:chahua/features/conversation/shared/domain/conversation_identity.dart';
import 'package:chahua/features/shared/model/message/message.dart';
import 'package:chahua/features/conversation/shared/domain/launch_request.dart';
import 'package:chahua/features/conversation/compose/presentation/conversation_compose_v2.dart';
import 'package:chahua/features/conversation/timeline/presentation/conversation_timeline_view.dart';
import 'package:chahua/features/conversation/shared/presentation/conversation_presentation_scope.dart';

class ConversationSurfaceV2 extends ConsumerStatefulWidget {
  const ConversationSurfaceV2({
    super.key,
    required this.identity,
    required this.launchRequest,
    this.onOpenThread,
    this.onStartThread,
    this.onMessageSent,
  });

  final ConversationIdentity identity;
  final LaunchRequest launchRequest;
  final void Function(ConversationMessageV2 message)? onOpenThread;
  final void Function(ConversationMessageV2 message)? onStartThread;
  final Future<void> Function()? onMessageSent;

  @override
  ConsumerState<ConversationSurfaceV2> createState() =>
      _ConversationSurfaceV2State();
}

class _ConversationSurfaceV2State extends ConsumerState<ConversationSurfaceV2> {
  final GlobalKey<ConversationComposeV2State> _composeKey =
      GlobalKey<ConversationComposeV2State>();
  late final AppRefreshCoordinator _refreshCoordinator;

  @override
  void initState() {
    super.initState();
    _refreshCoordinator = ref.read(appRefreshCoordinatorProvider);
    _registerRecovery();
  }

  @override
  void didUpdateWidget(ConversationSurfaceV2 oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity == widget.identity) {
      return;
    }
    _refreshCoordinator.unregisterConversationRecovery(oldWidget.identity);
    _registerRecovery();
  }

  @override
  void dispose() {
    _refreshCoordinator.unregisterConversationRecovery(widget.identity);
    super.dispose();
  }

  void _registerRecovery() {
    final identity = widget.identity;
    _refreshCoordinator.registerConversationRecovery(
      identity: identity,
      recover: (_) {
        if (!mounted) {
          return Future.value();
        }
        return ref
            .read(conversationTimelineViewModelProvider(identity).notifier)
            .recoverLatestAfterRefresh();
      },
    );
  }

  Future<void> _handleMessageSent() async {
    ref
        .read(conversationTimelineViewModelProvider(widget.identity).notifier)
        .followLatestTailIfNeeded();
    await widget.onMessageSent?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isThreadView = widget.identity.threadRootId != null;

    return ConversationPresentationScope(
      isThreadView: isThreadView,
      child: GestureDetector(
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
                  onStartThread: widget.onStartThread,
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
      ),
    );
  }
}
