import 'package:chahua/features/chats/conversation/domain/launch_request.dart';
import 'package:chahua/features/chats/conversation_v2/presentation/conversation_timeline_v2.dart';
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
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Chat V2')),
      child: SafeArea(
        child: ConversationTimelineV2(
          chatId: chatId,
          threadRootId: null,
          launchRequest: launchRequest,
        ),
      ),
    );
  }
}
