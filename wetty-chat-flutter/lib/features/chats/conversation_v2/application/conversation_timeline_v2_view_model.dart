import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chahua/features/chats/conversation/domain/launch_request.dart';
import 'package:chahua/features/chats/conversation/domain/conversation_message.dart';
import 'package:chahua/features/chats/conversation_v2/domain/conversation_message_v2.dart';
import 'package:chahua/features/chats/models/message_models.dart';

typedef ConversationTimelineV2Args = ({
  String chatId,
  String? threadRootId,
  LaunchRequest launchRequest,
});

typedef ConversationTimelineV2State = ({
  String chatId,
  String? threadRootId,
  LaunchRequest launchRequest,
  String title,
  List<ConversationMessageV2> messages,
});

class ConversationTimelineV2ViewModel
    extends AsyncNotifier<ConversationTimelineV2State> {
  final ConversationTimelineV2Args arg;

  ConversationTimelineV2ViewModel(this.arg);

  @override
  Future<ConversationTimelineV2State> build() async {
    final now = DateTime.now().toUtc();

    return (
      chatId: arg.chatId,
      threadRootId: arg.threadRootId,
      launchRequest: arg.launchRequest,
      title: arg.threadRootId == null
          ? 'Chat Timeline V2'
          : 'Thread Timeline V2',
      messages: List<ConversationMessageV2>.generate(
        50,
        (index) => _fakeMessage(now, index),
        growable: false,
      ),
    );
  }

  ConversationMessageV2 _fakeMessage(DateTime now, int index) {
    final isMe = index.isOdd;
    final sender = Sender(
      uid: isMe ? 1 : 2,
      name: isMe ? 'Me' : 'Alex',
      avatarUrl: null,
      gender: isMe ? 1 : 0,
    );

    final replyPreview = index % 9 == 0
        ? ReplyToMessage(
            id: 1000 + index,
            message: 'Earlier message preview',
            sender: const Sender(uid: 3, name: 'Taylor'),
          )
        : null;

    final reactions = index % 7 == 0
        ? const <ReactionSummary>[
            ReactionSummary(emoji: '👍', count: 2, reactedByMe: true),
          ]
        : const <ReactionSummary>[];

    final threadInfo = index % 8 == 0
        ? ThreadInfo(replyCount: 3 + (index % 4))
        : null;

    return ConversationMessageV2(
      serverMessageId: index + 1,
      clientGeneratedId:
          'fake-${arg.chatId}-${arg.threadRootId ?? 'chat'}-$index',
      sender: sender,
      createdAt: now.subtract(Duration(minutes: (50 - index) * 3)),
      isEdited: index % 11 == 0,
      isDeleted: index == 17,
      replyToMessage: replyPreview,
      reactions: reactions,
      threadInfo: threadInfo,
      deliveryState: isMe && index > 46
          ? ConversationDeliveryState.confirmed
          : ConversationDeliveryState.sent,
      content: _fakeContent(index),
    );
  }

  MessageContent _fakeContent(int index) {
    return TextMessageContent(
      text: 'Placeholder v2 message #$index for chat ${arg.chatId}',
      mentions: index % 13 == 0
          ? const <MentionInfo>[MentionInfo(uid: 9, username: 'casey')]
          : const <MentionInfo>[],
    );
  }
}

final conversationTimelineV2ViewModelProvider =
    AsyncNotifierProvider.family<
      ConversationTimelineV2ViewModel,
      ConversationTimelineV2State,
      ConversationTimelineV2Args
    >(ConversationTimelineV2ViewModel.new, isAutoDispose: true);
