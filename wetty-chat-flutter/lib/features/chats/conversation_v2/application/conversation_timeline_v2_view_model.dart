import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chahua/features/chats/conversation/domain/launch_request.dart';
import 'package:chahua/features/chats/conversation/domain/conversation_message.dart';
import 'package:chahua/features/chats/conversation_v2/domain/conversation_message_v2.dart';
import 'package:chahua/features/chats/conversation_v2/application/timeline_viewport_facts.dart';
import 'package:chahua/features/chats/conversation_v2/application/timeline_viewport_effect.dart';
import 'package:chahua/features/chats/models/message_models.dart';

typedef ConversationTimelineV2Identity = ({
  String chatId,
  String? threadRootId,
});

typedef ConversationTimelineV2State = ({
  List<ConversationMessageV2> messages,
  bool isResolvingJump,
  String? highlightedStableKey,
});

class ConversationTimelineV2ViewModel
    extends AsyncNotifier<ConversationTimelineV2State> {
  final ConversationTimelineV2Identity identity;
  LaunchRequest? _initialLaunchRequest;
  TimelineViewportFacts? _lastViewportFacts;
  final StreamController<TimelineViewportEffect> _effectsController =
      StreamController<TimelineViewportEffect>.broadcast();

  ConversationTimelineV2ViewModel(this.identity);

  Stream<TimelineViewportEffect> get effects => _effectsController.stream;

  @override
  Future<ConversationTimelineV2State> build() async {
    ref.onDispose(_effectsController.close);

    final now = DateTime.now().toUtc();

    return (
      messages: List<ConversationMessageV2>.generate(
        50,
        (index) => _fakeMessage(now, index),
        growable: false,
      ),
      isResolvingJump: false,
      highlightedStableKey: null,
    );
  }

  void initialize(LaunchRequest launchRequest) {
    if (_initialLaunchRequest == launchRequest) {
      return;
    }
    _initialLaunchRequest = launchRequest;
  }

  void onViewportChanged(TimelineViewportFacts facts) {
    final previousFacts = _lastViewportFacts;
    _lastViewportFacts = facts;

    if (previousFacts == null) {
      return;
    }

    if (previousFacts.isNearTop != facts.isNearTop ||
        previousFacts.isNearBottom != facts.isNearBottom) {
      // Placeholder seam for future timeline policy:
      // loading older/newer, pending-live updates, and live-edge decisions.
    }
  }

  void jumpToLatest() {
    _effectsController.add(const TimelineViewportEffect.revealBottom());
  }

  void jumpToMessage(String stableKey) {
    _effectsController.add(
      TimelineViewportEffect.revealMessage(
        stableKey,
        alignment: TimelineViewportAlignment.center,
        highlight: true,
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
          'fake-${identity.chatId}-${identity.threadRootId ?? 'chat'}-$index',
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
      text: 'Placeholder v2 message #$index for chat ${identity.chatId}',
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
      ConversationTimelineV2Identity
    >(ConversationTimelineV2ViewModel.new, isAutoDispose: true);
