import 'package:chahua/features/chats/conversation/domain/launch_request.dart';
import 'package:chahua/features/chats/conversation_v2/presentation/conversation_timeline_v2.dart';
import 'package:flutter/cupertino.dart';

class ThreadDetailV2Page extends StatelessWidget {
  const ThreadDetailV2Page({
    super.key,
    required this.chatId,
    required this.threadRootId,
    this.launchRequest = const LaunchRequest.latest(),
  });

  final String chatId;
  final String threadRootId;
  final LaunchRequest launchRequest;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Thread V2')),
      child: SafeArea(
        child: ConversationTimelineV2(
          args: (
            chatId: chatId,
            threadRootId: threadRootId,
            launchRequest: launchRequest,
          ),
        ),
      ),
    );
  }
}
