import 'package:chahua/features/chats/conversation_v2/domain/conversation_identity.dart';
import 'package:chahua/features/chats/conversation_v2/domain/launch_request.dart';
import 'package:chahua/features/chats/conversation_v2/presentation/conversation_surface_v2.dart';
import 'package:flutter/cupertino.dart';

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
      navigationBar: const CupertinoNavigationBar(middle: Text('Thread V2')),
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
