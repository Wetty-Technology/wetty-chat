import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/features/chats/conversation_v2/domain/conversation_identity.dart';
import 'package:chahua/features/chats/conversation_v2/domain/launch_request.dart';
import 'package:chahua/features/chats/conversation_v2/presentation/compose/conversation_v2_bottom_region.dart';
import 'package:chahua/features/chats/conversation_v2/presentation/compose/conversation_v2_composer_bar.dart';
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
    final ConversationIdentity identity = (
      chatId: chatId,
      threadRootId: threadRootId,
    );
    final colors = context.appColors;
    return CupertinoPageScaffold(
      resizeToAvoidBottomInset: false,
      navigationBar: const CupertinoNavigationBar(middle: Text('Thread V2')),
      child: SafeArea(
        bottom: false,
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  color: colors.chatBackground,
                  child: ConversationTimelineV2(
                    chatId: chatId,
                    threadRootId: threadRootId,
                    launchRequest: launchRequest,
                  ),
                ),
              ),
              ConversationV2BottomRegion(
                surfaceColor: colors.backgroundSecondary,
                borderColor: colors.inputBorder,
                composer: ConversationV2ComposerBar(identity: identity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
