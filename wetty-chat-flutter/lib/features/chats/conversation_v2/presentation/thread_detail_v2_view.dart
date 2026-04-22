import 'package:chahua/features/chats/conversation_v2/domain/conversation_identity.dart';
import 'package:chahua/features/chats/conversation_v2/domain/launch_request.dart';
import 'package:chahua/features/chats/conversation_v2/presentation/conversation_surface_v2.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../list_v2/application/thread_list_v2_store.dart';

class ThreadDetailV2Page extends StatelessWidget {
  const ThreadDetailV2Page({
    super.key,
    required this.chatId,
    required this.threadRootId,
    this.launchRequest = const LaunchRequest.latest(),
  });

  final int chatId;
  final int threadRootId;
  final LaunchRequest launchRequest;

  @override
  Widget build(BuildContext context) {
    final ConversationIdentity identity = (
      chatId: chatId,
      threadRootId: threadRootId,
    );
    return CupertinoPageScaffold(
      resizeToAvoidBottomInset: false,
      navigationBar: CupertinoNavigationBar(
        // TODO: Fix this, TheradDetail should take int
        middle: _ThreadDetailTitle(
          chatId: chatId.toString(),
          threadRootId: threadRootId.toString(),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: ConversationSurfaceV2(
          identity: identity,
          launchRequest: launchRequest,
        ),
      ),
    );
  }
}

class _ThreadDetailTitle extends ConsumerWidget {
  const _ThreadDetailTitle({required this.chatId, required this.threadRootId});

  final String chatId;
  final String threadRootId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thread = ref.watch(
      threadByIdProvider((chatId: chatId, threadRootId: threadRootId)),
    );
    final resolvedName = thread?.chatName.trim();
    // TODO(codex): Update the thread store when thread metadata changes so
    // renamed chats can update the title reactively without requiring a refetch.
    final title = resolvedName != null && resolvedName.isNotEmpty
        ? resolvedName
        : 'Thread $threadRootId';
    return Text(title);
  }
}
