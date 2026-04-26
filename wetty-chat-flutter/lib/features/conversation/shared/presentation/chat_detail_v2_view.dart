import 'package:chahua/features/conversation/shared/domain/conversation_identity.dart';
import 'package:chahua/features/conversation/shared/domain/launch_request.dart';
import 'package:chahua/features/shared/model/message/message.dart';
import 'package:chahua/features/conversation/shared/presentation/conversation_surface_v2.dart';
import 'package:chahua/features/chat_list/application/group_list_v2_store.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chahua/app/routing/route_names.dart';

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
        trailing: _ChatDetailActions(chatId: chatId),
      ),
      child: SafeArea(
        bottom: false,
        child: ConversationSurfaceV2(
          identity: identity,
          launchRequest: launchRequest,
          onOpenThread: (message) => _openThread(context, message),
          onStartThread: (message) => _startThread(context, message),
        ),
      ),
    );
  }

  void _openThread(BuildContext context, ConversationMessageV2 message) {
    final threadRootId = message.serverMessageId;
    if (threadRootId == null) {
      return;
    }
    context.push(AppRoutes.nestedThreadDetail('$chatId', '$threadRootId'));
  }

  void _startThread(BuildContext context, ConversationMessageV2 message) {
    final threadRootId = message.serverMessageId;
    if (threadRootId == null) {
      return;
    }
    context.push(AppRoutes.nestedNewThread('$chatId', '$threadRootId'));
  }
}

class _ChatDetailActions extends StatelessWidget {
  const _ChatDetailActions({required this.chatId});

  final int chatId;

  @override
  Widget build(BuildContext context) {
    final routeChatId = chatId.toString();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          minimumSize: const Size.square(36),
          onPressed: () => context.push(AppRoutes.chatMembers(routeChatId)),
          child: const Icon(CupertinoIcons.person_2),
        ),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          minimumSize: const Size.square(36),
          onPressed: () => context.push(AppRoutes.chatSettings(routeChatId)),
          child: const Icon(CupertinoIcons.info_circle),
        ),
      ],
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
