import 'package:chahua/features/chats/conversation_v2/domain/conversation_message_v2.dart';
import 'package:chahua/features/chats/conversation_v2/domain/conversation_timeline_v2_active_segment.dart';
import 'package:chahua/features/chats/conversation_v2/domain/conversation_timeline_v2_canonical_scope.dart';
import 'package:chahua/features/chats/conversation_v2/domain/conversation_timeline_v2_identity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef ConversationTimelineV2MessageStoreState =
    Map<ConversationTimelineV2Identity, ConversationTimelineV2CanonicalScope>;

class ConversationTimelineV2MessageStore
    extends Notifier<ConversationTimelineV2MessageStoreState> {
  @override
  ConversationTimelineV2MessageStoreState build() {
    return <
      ConversationTimelineV2Identity,
      ConversationTimelineV2CanonicalScope
    >{};
  }

  ConversationTimelineV2CanonicalScope? scopeFor(
    ConversationTimelineV2Identity identity,
  ) {
    return state[identity];
  }

  void putScope(
    ConversationTimelineV2Identity identity,
    ConversationTimelineV2CanonicalScope scope,
  ) {
    state =
        <ConversationTimelineV2Identity, ConversationTimelineV2CanonicalScope>{
          ...state,
          identity: scope,
        };
  }

  void markReachedOldest(ConversationTimelineV2Identity identity) {
    final existingScope = scopeFor(identity);
    if (existingScope == null) {
      return;
    }
    putScope(identity, (
      segments: existingScope.segments,
      hasLatestSegment: existingScope.hasLatestSegment,
      hasReachedOldest: true,
    ));
  }

  void insertBeforeAnchor(
    ConversationTimelineV2Identity identity,
    int anchorServerMessageId,
    ConversationTimelineV2CanonicalSegment segment,
  ) {
    assert(
      segment.lastServerMessageId < anchorServerMessageId,
      'insertBeforeAnchor requires the incoming segment to be strictly before the anchor',
    );
    final existingScope = scopeFor(identity);
    final segments = _normalizeBeforeAnchorSegments(
      existingScope?.segments ??
          const <ConversationTimelineV2CanonicalSegment>[],
      incoming: segment,
      anchorServerMessageId: anchorServerMessageId,
    );

    putScope(identity, (
      segments: segments,
      hasLatestSegment: existingScope?.hasLatestSegment ?? false,
      hasReachedOldest: existingScope?.hasReachedOldest ?? false,
    ));
  }

  void insertAfterAnchor(
    ConversationTimelineV2Identity identity,
    int anchorServerMessageId,
    ConversationTimelineV2CanonicalSegment segment,
  ) {
    assert(
      segment.firstServerMessageId > anchorServerMessageId,
      'insertAfterAnchor requires the incoming segment to be strictly after the anchor',
    );
    final existingScope = scopeFor(identity);
    final segments = _normalizeAfterAnchorSegments(
      existingScope?.segments ??
          const <ConversationTimelineV2CanonicalSegment>[],
      incoming: segment,
      anchorServerMessageId: anchorServerMessageId,
    );

    putScope(identity, (
      segments: segments,
      hasLatestSegment: existingScope?.hasLatestSegment ?? false,
      hasReachedOldest: existingScope?.hasReachedOldest ?? false,
    ));
  }

  void insertAround(
    ConversationTimelineV2Identity identity,
    ConversationTimelineV2CanonicalSegment segment,
  ) {
    final existingScope = scopeFor(identity);
    final segments = _normalizeAroundSegments(
      existingScope?.segments ??
          const <ConversationTimelineV2CanonicalSegment>[],
      incoming: segment,
    );

    putScope(identity, (
      segments: segments,
      hasLatestSegment: existingScope?.hasLatestSegment ?? false,
      hasReachedOldest: existingScope?.hasReachedOldest ?? false,
    ));
  }

  void insertLatest(
    ConversationTimelineV2Identity identity,
    ConversationTimelineV2CanonicalSegment segment,
  ) {
    final existingScope = scopeFor(identity);
    final segments = _normalizeLatestSegments(
      existingScope?.segments ??
          const <ConversationTimelineV2CanonicalSegment>[],
      incoming: segment,
    );

    putScope(identity, (
      segments: segments,
      hasLatestSegment: true,
      hasReachedOldest: existingScope?.hasReachedOldest ?? false,
    ));
  }

  void insertLatestMessage(
    ConversationTimelineV2Identity identity,
    ConversationMessageV2 message,
  ) {
    final serverMessageId = message.serverMessageId;
    assert(
      serverMessageId != null,
      'insertLatestMessage requires a server-backed message',
    );

    final existingScope = scopeFor(identity);
    final existingSegments =
        existingScope?.segments ??
        const <ConversationTimelineV2CanonicalSegment>[];

    if ((existingScope?.hasLatestSegment ?? false) && existingSegments.isNotEmpty) {
      final latestSegment = existingSegments.last;
      assert(
        serverMessageId! > latestSegment.lastServerMessageId,
        'insertLatestMessage requires the new message to be newer than the current latest tail',
      );
      final updatedLatestSegment = ConversationTimelineV2CanonicalSegment(
        orderedMessages: [...latestSegment.orderedMessages, message],
      );
      putScope(identity, (
        segments: [
          ...existingSegments.take(existingSegments.length - 1),
          updatedLatestSegment,
        ],
        hasLatestSegment: true,
        hasReachedOldest: existingScope?.hasReachedOldest ?? false,
      ));
      return;
    }

    putScope(identity, (
      segments: [
        ...existingSegments,
        ConversationTimelineV2CanonicalSegment(orderedMessages: [message]),
      ],
      hasLatestSegment: true,
      hasReachedOldest: existingScope?.hasReachedOldest ?? false,
    ));
  }

  List<ConversationTimelineV2CanonicalSegment> _normalizeBeforeAnchorSegments(
    List<ConversationTimelineV2CanonicalSegment> existingSegments, {
    required ConversationTimelineV2CanonicalSegment incoming,
    required int anchorServerMessageId,
  }) {
    final incomingStartId = incoming.firstServerMessageId;

    final result = <ConversationTimelineV2CanonicalSegment>[];
    var emittedIncoming = false;

    for (final existing in existingSegments) {
      if (emittedIncoming) {
        result.add(existing);
        continue;
      }

      if (existing.endsBeforeServerMessageId(incomingStartId)) {
        result.add(existing);
        continue;
      }

      if (existing.endsBeforeServerMessageId(anchorServerMessageId)) {
        final prefix = existing.messagesBefore(incomingStartId);
        if (prefix != null) {
          result.add(prefix);
        }
        continue;
      }

      final prefix = existing.messagesBefore(incomingStartId);
      if (prefix != null) {
        result.add(prefix);
      }
      final suffix = existing.messagesFrom(anchorServerMessageId);
      result.add(_concatenateSegments(incoming, suffix));
      emittedIncoming = true;
    }

    if (!emittedIncoming) {
      result.add(incoming);
    }

    return result;
  }

  List<ConversationTimelineV2CanonicalSegment> _normalizeAfterAnchorSegments(
    List<ConversationTimelineV2CanonicalSegment> existingSegments, {
    required ConversationTimelineV2CanonicalSegment incoming,
    required int anchorServerMessageId,
  }) {
    final incomingEndId = incoming.lastServerMessageId;

    final result = <ConversationTimelineV2CanonicalSegment>[];
    var emittedIncoming = false;
    var pendingIncoming = incoming;

    for (final existing in existingSegments) {
      if (emittedIncoming) {
        result.add(existing);
        continue;
      }

      if (existing.endsBeforeServerMessageId(anchorServerMessageId)) {
        result.add(existing);
        continue;
      }

      if (existing.startsAfterServerMessageId(incomingEndId)) {
        if (!emittedIncoming) {
          result.add(pendingIncoming);
          emittedIncoming = true;
        }
        result.add(existing);
        continue;
      }

      final prefix = existing.messagesThrough(anchorServerMessageId);
      if (prefix != null) {
        pendingIncoming = _concatenateSegments(prefix, incoming);
      }
      final suffix = existing.messagesAfter(incomingEndId);
      if (suffix != null) {
        result.add(pendingIncoming);
        emittedIncoming = true;
        result.add(suffix);
      }
    }

    if (!emittedIncoming) {
      result.add(pendingIncoming);
    }

    return result;
  }

  List<ConversationTimelineV2CanonicalSegment> _normalizeAroundSegments(
    List<ConversationTimelineV2CanonicalSegment> existingSegments, {
    required ConversationTimelineV2CanonicalSegment incoming,
  }) {
    final incomingStartId = incoming.firstServerMessageId;
    final incomingEndId = incoming.lastServerMessageId;

    final result = <ConversationTimelineV2CanonicalSegment>[];
    var emittedIncoming = false;

    for (final existing in existingSegments) {
      if (existing.endsBeforeServerMessageId(incomingStartId)) {
        result.add(existing);
        continue;
      }

      if (existing.startsAfterServerMessageId(incomingEndId)) {
        if (!emittedIncoming) {
          result.add(incoming);
          emittedIncoming = true;
        }
        result.add(existing);
        continue;
      }

      final prefix = existing.messagesBefore(incomingStartId);
      if (prefix != null) {
        result.add(prefix);
      }
      if (!emittedIncoming) {
        result.add(incoming);
        emittedIncoming = true;
      }
      final suffix = existing.messagesAfter(incomingEndId);
      if (suffix != null) {
        result.add(suffix);
      }
    }

    if (!emittedIncoming) {
      result.add(incoming);
    }

    return result;
  }

  List<ConversationTimelineV2CanonicalSegment> _normalizeLatestSegments(
    List<ConversationTimelineV2CanonicalSegment> existingSegments, {
    required ConversationTimelineV2CanonicalSegment incoming,
  }) {
    final incomingStartId = incoming.firstServerMessageId;

    final result = <ConversationTimelineV2CanonicalSegment>[];
    var insertedIncoming = false;

    for (final existing in existingSegments) {
      if (insertedIncoming) {
        continue;
      }

      if (existing.endsBeforeServerMessageId(incomingStartId)) {
        result.add(existing);
        continue;
      }

      final prefix = existing.messagesBefore(incomingStartId);
      if (prefix != null) {
        result.add(prefix);
      }
      result.add(incoming);
      insertedIncoming = true;
    }

    if (!insertedIncoming) {
      result.add(incoming);
    }

    return result;
  }

  ConversationTimelineV2CanonicalSegment _concatenateSegments(
    ConversationTimelineV2CanonicalSegment left,
    ConversationTimelineV2CanonicalSegment? right,
  ) {
    if (right == null) {
      return left;
    }

    return ConversationTimelineV2CanonicalSegment(
      orderedMessages: [...left.orderedMessages, ...right.orderedMessages],
    );
  }
}

final conversationTimelineV2MessageStoreProvider =
    NotifierProvider<
      ConversationTimelineV2MessageStore,
      ConversationTimelineV2MessageStoreState
    >(ConversationTimelineV2MessageStore.new);

typedef ConversationTimelineV2ActiveSegmentProviderArgs = ({
  ConversationTimelineV2Identity identity,
  ConversationTimelineV2ActiveSegmentMode mode,
});

final conversationTimelineV2ActiveSegmentProvider =
    Provider.family<
      ConversationTimelineV2ActiveSegment?,
      ConversationTimelineV2ActiveSegmentProviderArgs
    >((ref, args) {
      final scope = ref.watch(
        conversationTimelineV2MessageStoreProvider.select(
          (state) => state[args.identity],
        ),
      );
      if (scope == null || scope.segments.isEmpty) {
        return null;
      }

      if (args.mode.isLatest) {
        if (!scope.hasLatestSegment) {
          return null;
        }

        final latestSegment = scope.segments.last;
        return _activeSegmentForScopeSegment(
          scope,
          latestSegment,
          selectedIndex: scope.segments.length - 1,
        );
      }

      final targetServerMessageId = args.mode.targetServerMessageId;
      if (targetServerMessageId == null) {
        return null;
      }

      for (var index = 0; index < scope.segments.length; index++) {
        final segment = scope.segments[index];
        if (segment.firstServerMessageId <= targetServerMessageId &&
            segment.lastServerMessageId >= targetServerMessageId) {
          return _activeSegmentForScopeSegment(
            scope,
            segment,
            selectedIndex: index,
          );
        }
      }

      return null;
    });

ConversationTimelineV2ActiveSegment _activeSegmentForScopeSegment(
  ConversationTimelineV2CanonicalScope scope,
  ConversationTimelineV2CanonicalSegment selectedSegment, {
  required int selectedIndex,
}) {
  final isLatestSegment =
      scope.hasLatestSegment && selectedIndex == scope.segments.length - 1;
  final isFirstSegment = selectedIndex == 0;

  return (
    orderedMessages: selectedSegment.orderedMessages,
    canLoadBefore: !isFirstSegment || !scope.hasReachedOldest,
    canLoadAfter: !isLatestSegment,
  );
}
