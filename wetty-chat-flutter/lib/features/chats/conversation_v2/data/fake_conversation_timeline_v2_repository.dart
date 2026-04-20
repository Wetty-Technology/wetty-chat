import 'package:chahua/features/chats/conversation/domain/conversation_message.dart';
import 'package:chahua/features/chats/conversation_v2/application/conversation_timeline_v2_message_store.dart';
import 'package:chahua/features/chats/conversation_v2/domain/conversation_message_v2.dart';
import 'package:chahua/features/chats/conversation_v2/domain/conversation_timeline_v2_canonical_scope.dart';
import 'package:chahua/features/chats/conversation_v2/domain/conversation_timeline_v2_identity.dart';
import 'package:chahua/features/chats/models/message_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'conversation_timeline_v2_repository.dart';

class FakeConversationTimelineV2Repository
    implements ConversationTimelineV2Repository {
  FakeConversationTimelineV2Repository(this.ref, this.identity)
    : _baseNow = DateTime.now().toUtc();

  final Ref ref;
  final ConversationTimelineV2Identity identity;
  final DateTime _baseNow;

  @override
  Future<void> refreshLatestSegment({required int limit}) async {
    final existingScope = ref.read(
      conversationTimelineV2MessageStoreProvider,
    )[identity];
    if (existingScope?.hasLatestSegment ?? false) {
      return;
    }

    final latestSegment = ConversationTimelineV2CanonicalSegment(
      orderedMessages: List<ConversationMessageV2>.generate(
        limit,
        (index) => _buildMessage(identity, sequence: index, baseNow: _baseNow),
        growable: false,
      ),
    );

    ref
        .read(conversationTimelineV2MessageStoreProvider.notifier)
        .insertLatest(identity, latestSegment);
  }

  @override
  Future<void> loadOlderBeforeAnchor(
    int anchorServerMessageId, {
    required int limit,
  }) async {
    final firstOlderServerMessageId = anchorServerMessageId - limit;
    final olderSegment = ConversationTimelineV2CanonicalSegment(
      orderedMessages: List<ConversationMessageV2>.generate(limit, (index) {
        final serverMessageId = firstOlderServerMessageId + index;
        final sequence = serverMessageId - 1;
        return _buildMessage(identity, sequence: sequence, baseNow: _baseNow);
      }, growable: false),
    );

    ref
        .read(conversationTimelineV2MessageStoreProvider.notifier)
        .insertBeforeAnchor(identity, anchorServerMessageId, olderSegment);
  }

  @override
  Future<void> loadNewerAfterAnchor(
    int anchorServerMessageId, {
    required int limit,
  }) async {
    final firstNewerServerMessageId = anchorServerMessageId + 1;
    final newerSegment = ConversationTimelineV2CanonicalSegment(
      orderedMessages: List<ConversationMessageV2>.generate(limit, (index) {
        final serverMessageId = firstNewerServerMessageId + index;
        final sequence = serverMessageId - 1;
        return _buildMessage(identity, sequence: sequence, baseNow: _baseNow);
      }, growable: false),
    );

    ref
        .read(conversationTimelineV2MessageStoreProvider.notifier)
        .insertAfterAnchor(identity, anchorServerMessageId, newerSegment);
  }

  @override
  Future<void> refreshAroundServerMessageId(
    int targetServerMessageId, {
    required int limit,
  }) async {
    final halfWindow = limit ~/ 2;
    final firstServerMessageId = targetServerMessageId - halfWindow;
    final aroundSegment = ConversationTimelineV2CanonicalSegment(
      orderedMessages: List<ConversationMessageV2>.generate(limit, (index) {
        final serverMessageId = firstServerMessageId + index;
        final sequence = serverMessageId - 1;
        return _buildMessage(identity, sequence: sequence, baseNow: _baseNow);
      }, growable: false),
    );

    ref
        .read(conversationTimelineV2MessageStoreProvider.notifier)
        .insertAround(identity, aroundSegment);
  }

  @override
  Future<void> addLatestFakeMessage() async {
    final existingScope = ref.read(
      conversationTimelineV2MessageStoreProvider,
    )[identity];
    final nextServerMessageId = existingScope?.segments.isNotEmpty ?? false
        ? existingScope!.segments.last.lastServerMessageId + 1
        : 1;
    final nextSequence = nextServerMessageId - 1;
    final nextMessage = _buildMessage(
      identity,
      sequence: nextSequence,
      baseNow: _baseNow,
    );

    ref
        .read(conversationTimelineV2MessageStoreProvider.notifier)
        .insertLatestMessage(identity, nextMessage);
  }

  ConversationMessageV2 _buildMessage(
    ConversationTimelineV2Identity identity, {
    required int sequence,
    required DateTime baseNow,
  }) {
    final isMe = sequence.isOdd;
    final sender = Sender(
      uid: isMe ? 1 : 2,
      name: isMe ? 'Me' : 'Alex',
      avatarUrl: null,
      gender: isMe ? 1 : 0,
    );

    final replyPreview = sequence % 9 == 0
        ? ReplyToMessage(
            id: 1000 + sequence,
            message: 'Earlier message preview',
            sender: const Sender(uid: 3, name: 'Taylor'),
          )
        : null;

    final reactions = sequence % 7 == 0
        ? const <ReactionSummary>[
            ReactionSummary(emoji: '👍', count: 2, reactedByMe: true),
          ]
        : const <ReactionSummary>[];

    final threadInfo = sequence % 8 == 0
        ? ThreadInfo(replyCount: 3 + (sequence % 4).abs())
        : null;

    return ConversationMessageV2(
      serverMessageId: sequence + 1,
      clientGeneratedId:
          'fake-${identity.chatId}-${identity.threadRootId ?? 'chat'}-$sequence',
      sender: sender,
      createdAt: baseNow.subtract(
        Duration(minutes: (limitSeed - sequence) * 3),
      ),
      isEdited: sequence % 11 == 0,
      isDeleted: sequence == 17,
      replyToMessage: replyPreview,
      reactions: reactions,
      threadInfo: threadInfo,
      deliveryState: isMe && sequence > 46
          ? ConversationDeliveryState.confirmed
          : ConversationDeliveryState.sent,
      content: _buildContent(identity, sequence),
    );
  }

  MessageContent _buildContent(
    ConversationTimelineV2Identity identity,
    int sequence,
  ) {
    return TextMessageContent(
      text: 'Placeholder v2 message #$sequence for chat ${identity.chatId}',
      mentions: sequence % 13 == 0
          ? const <MentionInfo>[MentionInfo(uid: 9, username: 'casey')]
          : const <MentionInfo>[],
    );
  }

  static const int limitSeed = 120;
}

final fakeConversationTimelineV2RepositoryProvider =
    Provider.family<
      FakeConversationTimelineV2Repository,
      ConversationTimelineV2Identity
    >((ref, identity) => FakeConversationTimelineV2Repository(ref, identity));
