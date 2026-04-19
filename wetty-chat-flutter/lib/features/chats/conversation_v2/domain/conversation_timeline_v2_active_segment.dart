import 'package:chahua/features/chats/conversation_v2/domain/conversation_message_v2.dart';

/// A single contiguous working segment handed from the repository to the view
/// model. Unlike the canonical store, which may cache multiple discontiguous
/// segments, the view model only consumes one active segment at a time.
typedef ConversationTimelineV2ActiveSegment = ({
  List<ConversationMessageV2> orderedMessages,
  bool canLoadBefore,
  bool canLoadAfter,
});
