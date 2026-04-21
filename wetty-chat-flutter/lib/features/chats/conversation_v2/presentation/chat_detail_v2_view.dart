import 'package:chahua/features/chats/conversation_v2/domain/conversation_identity.dart';
import 'package:chahua/features/chats/conversation_v2/domain/launch_request.dart';
import 'package:chahua/features/chats/conversation_v2/presentation/conversation_surface_v2.dart';
import 'package:flutter/cupertino.dart';

class ChatDetailV2Page extends StatelessWidget {
  const ChatDetailV2Page({
    super.key,
    required this.chatId,
    this.launchRequest = const LaunchRequest.latest(),
  });

  final String chatId;
  final LaunchRequest launchRequest;

  @override
  Widget build(BuildContext context) {
    final ConversationIdentity identity = (chatId: chatId, threadRootId: null);
    return CupertinoPageScaffold(
      resizeToAvoidBottomInset: false,
      navigationBar: const CupertinoNavigationBar(middle: Text('Chat V2')),
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
