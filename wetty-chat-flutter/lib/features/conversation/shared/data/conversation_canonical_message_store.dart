import 'package:chahua/features/conversation/shared/domain/conversation_message_v2.dart';
import 'package:chahua/features/conversation/shared/domain/conversation_timeline_v2_active_segment.dart';
import 'package:chahua/features/conversation/shared/domain/conversation_timeline_v2_canonical_scope.dart';
import 'package:chahua/features/conversation/shared/domain/conversation_identity.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef ConversationTimelineV2MessageStoreState =
    Map<ConversationIdentity, ConversationTimelineV2CanonicalScope>;

class ConversationTimelineV2MessageStore
    extends Notifier<ConversationTimelineV2MessageStoreState> {
  @override
  ConversationTimelineV2MessageStoreState build() {
    return <ConversationIdentity, ConversationTimelineV2CanonicalScope>{};
  }

  ConversationTimelineV2CanonicalScope? scopeFor(
    ConversationIdentity identity,
  ) {
    return state[identity];
  }

  ConversationMessageV2? messageForServerMessageId(
    ConversationIdentity identity,
    int serverMessageId,
  ) {
    final existingScope = scopeFor(identity);
    if (existingScope == null) {
      return null;
    }

    for (final segment in existingScope.segments) {
      for (final message in segment.orderedMessages) {
        if (message.serverMessageId == serverMessageId) {
          return message;
        }
      }
    }

    for (final message in existingScope.optimisticMessages) {
      if (message.serverMessageId == serverMessageId) {
        return message;
      }
    }

    return null;
  }

  void putScope(
    ConversationIdentity identity,
    ConversationTimelineV2CanonicalScope scope,
  ) {
    state = <ConversationIdentity, ConversationTimelineV2CanonicalScope>{
      ...state,
      identity: scope,
    };
  }

  void markReachedOldest(ConversationIdentity identity) {
    final existingScope = scopeFor(identity);
    if (existingScope == null) {
      return;
    }
    putScope(identity, existingScope.copyWith(hasReachedOldest: true));
  }

  void insertBeforeAnchor(
    ConversationIdentity identity,
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

    putScope(
      identity,
      (existingScope ?? const ConversationTimelineV2CanonicalScope()).copyWith(
        segments: segments,
      ),
    );
  }

  void insertAfterAnchor(
    ConversationIdentity identity,
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

    putScope(
      identity,
      (existingScope ?? const ConversationTimelineV2CanonicalScope()).copyWith(
        segments: segments,
      ),
    );
  }

  void insertAround(
    ConversationIdentity identity,
    ConversationTimelineV2CanonicalSegment segment,
  ) {
    final existingScope = scopeFor(identity);
    final segments = _normalizeAroundSegments(
      existingScope?.segments ??
          const <ConversationTimelineV2CanonicalSegment>[],
      incoming: segment,
    );

    putScope(
      identity,
      (existingScope ?? const ConversationTimelineV2CanonicalScope()).copyWith(
        segments: segments,
      ),
    );
  }

  void insertLatest(
    ConversationIdentity identity,
    ConversationTimelineV2CanonicalSegment segment,
  ) {
    final existingScope = scopeFor(identity);
    final segments = _normalizeLatestSegments(
      existingScope?.segments ??
          const <ConversationTimelineV2CanonicalSegment>[],
      incoming: segment,
    );

    putScope(
      identity,
      (existingScope ?? const ConversationTimelineV2CanonicalScope()).copyWith(
        segments: segments,
        hasLatestSegment: true,
      ),
    );
  }

  void newMessage(
    ConversationIdentity identity,
    ConversationMessageV2 message,
  ) {
    if (message.serverMessageId == null) {
      _newOptimisticMessage(identity, message);
      return;
    }
    _newServerBackedMessage(identity, message);
  }

  void _newServerBackedMessage(
    ConversationIdentity identity,
    ConversationMessageV2 message,
  ) {
    final existingScope = scopeFor(identity);
    if (existingScope == null || !existingScope.hasLatestSegment) {
      return;
    }

    final optimisticMessages = existingScope.optimisticMessages
        .where((item) => item.clientGeneratedId != message.clientGeneratedId)
        .toList(growable: false);
    final latestSegment = existingScope.segments.isEmpty
        ? null
        : existingScope.segments.last;
    if (latestSegment == null) {
      return;
    }

    final updatedLatestMessages = _mergeLatestMessages(
      latestSegment.orderedMessages,
      message,
    );

    putScope(
      identity,
      existingScope.copyWith(
        optimisticMessages: optimisticMessages,
        segments: [
          ...existingScope.segments.take(existingScope.segments.length - 1),
          ConversationTimelineV2CanonicalSegment(
            orderedMessages: updatedLatestMessages,
          ),
        ],
        hasLatestSegment: true,
      ),
    );
  }

  void _newOptimisticMessage(
    ConversationIdentity identity,
    ConversationMessageV2 message,
  ) {
    assert(
      message.serverMessageId == null,
      '_newOptimisticMessage requires a local-only message',
    );

    final existingScope = scopeFor(identity);
    final optimisticMessages =
        (existingScope?.optimisticMessages ?? const <ConversationMessageV2>[])
            .toList(growable: true);

    for (var index = 0; index < optimisticMessages.length; index++) {
      if (optimisticMessages[index].clientGeneratedId !=
          message.clientGeneratedId) {
        continue;
      }
      optimisticMessages[index] = message;
      putScope(
        identity,
        (existingScope ?? const ConversationTimelineV2CanonicalScope())
            .copyWith(
              hasLatestSegment: true,
              optimisticMessages: optimisticMessages.toList(growable: false),
            ),
      );
      return;
    }

    optimisticMessages.add(message);

    putScope(
      identity,
      (existingScope ?? const ConversationTimelineV2CanonicalScope()).copyWith(
        hasLatestSegment: true,
        optimisticMessages: optimisticMessages.toList(growable: false),
      ),
    );
  }

  bool updateMessage(
    ConversationIdentity identity,
    ConversationMessageV2 message,
  ) {
    final serverMessageId = message.serverMessageId;
    assert(
      serverMessageId != null,
      'updateMessage requires a server-backed message',
    );

    final existingScope = scopeFor(identity);
    if (existingScope == null) {
      return false;
    }

    var replaced = false;
    final segments = existingScope.segments
        .map((segment) {
          var segmentReplaced = false;
          final updatedMessages = segment.orderedMessages
              .map((existingMessage) {
                if (existingMessage.serverMessageId != serverMessageId) {
                  return existingMessage;
                }
                replaced = true;
                segmentReplaced = true;
                return message;
              })
              .toList(growable: false);
          return segmentReplaced
              ? ConversationTimelineV2CanonicalSegment(
                  orderedMessages: updatedMessages,
                )
              : segment;
        })
        .toList(growable: false);

    if (!replaced) {
      return false;
    }

    putScope(identity, existingScope.copyWith(segments: segments));
    return true;
  }

  bool deleteMessage(ConversationIdentity identity, int serverMessageId) {
    final existingScope = scopeFor(identity);
    if (existingScope == null) {
      return false;
    }

    var removed = false;
    final segments = existingScope.segments
        .expand((segment) {
          final remainingMessages = segment.orderedMessages
              .where((message) {
                final keep = message.serverMessageId != serverMessageId;
                if (!keep) {
                  removed = true;
                }
                return keep;
              })
              .toList(growable: false);
          if (remainingMessages.isEmpty) {
            return const <ConversationTimelineV2CanonicalSegment>[];
          }
          return <ConversationTimelineV2CanonicalSegment>[
            ConversationTimelineV2CanonicalSegment(
              orderedMessages: remainingMessages,
            ),
          ];
        })
        .toList(growable: false);

    if (!removed) {
      return false;
    }

    putScope(identity, existingScope.copyWith(segments: segments));
    return true;
  }

  List<ConversationMessageV2> _mergeLatestMessages(
    List<ConversationMessageV2> existingMessages,
    ConversationMessageV2 incoming,
  ) {
    final incomingServerMessageId = incoming.serverMessageId;
    assert(
      incomingServerMessageId != null,
      '_mergeLatestMessages requires a server-backed message',
    );
    if (incomingServerMessageId == null) {
      return existingMessages;
    }

    final updated = existingMessages.toList(growable: true);

    for (var index = updated.length - 1; index >= 0; index--) {
      final current = updated[index];
      final currentServerMessageId = current.serverMessageId;
      assert(
        currentServerMessageId != null,
        '_mergeLatestMessages only operates on server-backed latest messages',
      );
      if (currentServerMessageId == null) {
        continue;
      }

      if (currentServerMessageId == incomingServerMessageId) {
        updated[index] = incoming;
        return updated.toList(growable: false);
      }

      if (currentServerMessageId < incomingServerMessageId) {
        updated.insert(index + 1, incoming);
        return updated.toList(growable: false);
      }
    }

    updated.insert(0, incoming);
    return updated.toList(growable: false);
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
  ConversationIdentity identity,
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
      if (scope == null) {
        return null;
      }

      if (args.mode.isLatest) {
        if (!scope.hasLatestSegment) {
          return null;
        }

        if (scope.segments.isEmpty) {
          if (scope.optimisticMessages.isEmpty) {
            return null;
          }
          return (
            orderedMessages: scope.optimisticMessages,
            canLoadBefore: !scope.hasReachedOldest,
            canLoadAfter: false,
            isLatestSlice: true,
          );
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
  final orderedMessages = isLatestSegment
      ? _mergeLatestSliceMessages(
          selectedSegment.orderedMessages,
          scope.optimisticMessages,
        )
      : selectedSegment.orderedMessages;

  return (
    orderedMessages: orderedMessages,
    canLoadBefore: !isFirstSegment || !scope.hasReachedOldest,
    canLoadAfter: !isLatestSegment,
    isLatestSlice: isLatestSegment,
  );
}

List<ConversationMessageV2> _mergeLatestSliceMessages(
  List<ConversationMessageV2> canonicalMessages,
  List<ConversationMessageV2> optimisticMessages,
) {
  if (optimisticMessages.isEmpty) {
    return canonicalMessages;
  }

  final canonicalClientIds = canonicalMessages
      .map((message) => message.clientGeneratedId)
      .where((clientGeneratedId) => clientGeneratedId.isNotEmpty)
      .toSet();
  final mergedOptimisticMessages = optimisticMessages
      .where(
        (message) => !canonicalClientIds.contains(message.clientGeneratedId),
      )
      .toList(growable: false);
  if (mergedOptimisticMessages.isEmpty) {
    return canonicalMessages;
  }

  return [...canonicalMessages, ...mergedOptimisticMessages];
}
