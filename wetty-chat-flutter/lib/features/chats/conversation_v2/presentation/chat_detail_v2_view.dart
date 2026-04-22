import 'package:chahua/features/chats/conversation_v2/domain/conversation_identity.dart';
import 'package:chahua/features/chats/conversation_v2/domain/launch_request.dart';
import 'package:chahua/features/chats/conversation_v2/presentation/conversation_surface_v2.dart';
import 'package:chahua/features/chats/list_v2/application/group_list_v2_store.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ChatDetailV2Page extends StatelessWidget {
  const ChatDetailV2Page({
    super.key,
    required this.chatId,
    this.launchRequest = const LaunchRequest.latest(),
  });

  final int chatId;
  final LaunchRequest launchRequest;

  @override
  Widget build(BuildContext context) {
    final ConversationIdentity identity = (chatId: chatId, threadRootId: null);
    return CupertinoPageScaffold(
      resizeToAvoidBottomInset: false,
      navigationBar: CupertinoNavigationBar(
        middle: _ChatDetailTitle(chatId: chatId),
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

class _ChatDetailTitle extends ConsumerWidget {
  const _ChatDetailTitle({required this.chatId});

  final int chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(groupByIdProvider(chatId.toString()));
    final resolvedName = group?.name?.trim();
    final title = resolvedName != null && resolvedName.isNotEmpty
        ? resolvedName
        : 'Chat $chatId';
    return Text(title);
  }
}
