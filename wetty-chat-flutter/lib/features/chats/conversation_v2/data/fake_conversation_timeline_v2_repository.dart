import 'package:chahua/features/chats/conversation/domain/conversation_message.dart';
import 'package:chahua/features/chats/conversation_v2/application/conversation_timeline_v2_view_model.dart';
import 'package:chahua/features/chats/conversation_v2/domain/conversation_message_v2.dart';
import 'package:chahua/features/chats/conversation_v2/domain/conversation_timeline_v2_window.dart';
import 'package:chahua/features/chats/models/message_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FakeConversationTimelineV2Repository {
  FakeConversationTimelineV2Repository(this.identity)
    : _baseNow = DateTime.now().toUtc(),
      _history = <ConversationMessageV2>[] {
    _history.addAll(
      List<ConversationMessageV2>.generate(
        fakeHistoryCount,
        (sequence) =>
            _buildMessage(identity, sequence: sequence, baseNow: _baseNow),
        growable: false,
      ),
    );
  }

  static const int fakeHistoryCount = 120;

  final ConversationTimelineV2Identity identity;
  final DateTime _baseNow;
  final List<ConversationMessageV2> _history;

  ConversationTimelineV2Window buildInitialAnchoredWindow({
    required int loadedWindowSize,
  }) {
    return windowAroundHistoryIndex(
      _history.length ~/ 2,
      loadedWindowSize: loadedWindowSize,
    );
  }

  ConversationTimelineV2Window latestWindow({required int limit}) {
    final startIndex = (_history.length - limit).clamp(0, _history.length);
    return (
      beforeMessages: _history.sublist(startIndex),
      afterMessages: const <ConversationMessageV2>[],
      canLoadOlder: startIndex > 0,
      canLoadNewer: false,
    );
  }

  ConversationTimelineV2Window windowAroundHistoryIndex(
    int historyIndex, {
    required int loadedWindowSize,
  }) {
    final windowRadius = loadedWindowSize ~/ 2;
    final startIndex = (historyIndex - windowRadius).clamp(
      0,
      _history.length - 1,
    );
    final endExclusive = (startIndex + loadedWindowSize).clamp(
      0,
      _history.length,
    );
    final correctedStartIndex = (endExclusive - loadedWindowSize).clamp(
      0,
      _history.length - 1,
    );

    return (
      beforeMessages: _history.sublist(correctedStartIndex, historyIndex),
      afterMessages: _history.sublist(historyIndex, endExclusive),
      canLoadOlder: true,
      canLoadNewer: endExclusive < _history.length,
    );
  }

  ConversationTimelineV2Window? windowAroundStableKey(
    String stableKey, {
    required int loadedWindowSize,
  }) {
    final historyIndex = _history.indexWhere(
      (message) => message.stableKey == stableKey,
    );
    if (historyIndex < 0) {
      return null;
    }

    return windowAroundHistoryIndex(
      historyIndex,
      loadedWindowSize: loadedWindowSize,
    );
  }

  ConversationTimelineV2Window? windowAroundServerMessageId(
    int serverMessageId, {
    required int loadedWindowSize,
  }) {
    final historyIndex = _history.indexWhere(
      (message) => message.serverMessageId == serverMessageId,
    );
    if (historyIndex < 0) {
      return null;
    }

    return windowAroundHistoryIndex(
      historyIndex,
      loadedWindowSize: loadedWindowSize,
    );
  }

  ConversationMessageV2 appendLatest() {
    final nextSequence = _history.isEmpty
        ? 0
        : messageSequence(_history.last) + 1;
    final message = _buildMessage(
      identity,
      sequence: nextSequence,
      baseNow: _baseNow,
    );
    _history.add(message);
    return message;
  }

  ConversationMessageV2? findByStableKey(String stableKey) {
    for (final message in _history) {
      if (message.stableKey == stableKey) {
        return message;
      }
    }
    return null;
  }

  ConversationMessageV2? findByServerMessageId(int serverMessageId) {
    for (final message in _history) {
      if (message.serverMessageId == serverMessageId) {
        return message;
      }
    }
    return null;
  }

  List<ConversationMessageV2> loadOlderPage({
    required ConversationMessageV2 earliestLoadedMessage,
    required int pageSize,
  }) {
    final startIndex = _history.indexOf(earliestLoadedMessage);
    if (startIndex > 0) {
      final newStartIndex = (startIndex - pageSize).clamp(0, _history.length);
      return _history.sublist(newStartIndex, startIndex);
    }

    final earliestSequence = messageSequence(earliestLoadedMessage);
    return List<ConversationMessageV2>.generate(
      pageSize,
      (index) => _buildMessage(
        identity,
        sequence: earliestSequence - pageSize + index,
        baseNow: _baseNow,
      ),
      growable: false,
    );
  }

  List<ConversationMessageV2> loadNewerPage({
    required ConversationMessageV2 latestLoadedMessage,
    required int pageSize,
  }) {
    final endIndex = _history.indexOf(latestLoadedMessage);
    final newEndExclusive = (endIndex + 1 + pageSize).clamp(0, _history.length);
    return _history.sublist(endIndex + 1, newEndExclusive);
  }

  bool hasNewerThan(ConversationMessageV2 message) {
    final historyIndex = _history.indexOf(message);
    return historyIndex >= 0 && historyIndex < _history.length - 1;
  }

  int messageSequence(ConversationMessageV2 message) {
    final suffix = message.clientGeneratedId.split('-').last;
    return int.tryParse(suffix) ?? 0;
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
      serverMessageId: sequence >= 0 ? sequence + 1 : null,
      clientGeneratedId:
          'fake-${identity.chatId}-${identity.threadRootId ?? 'chat'}-$sequence',
      sender: sender,
      createdAt: baseNow.subtract(
        Duration(minutes: (fakeHistoryCount - sequence) * 3),
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
}

final fakeConversationTimelineV2RepositoryProvider =
    Provider.family<
      FakeConversationTimelineV2Repository,
      ConversationTimelineV2Identity
    >((ref, identity) => FakeConversationTimelineV2Repository(identity));
