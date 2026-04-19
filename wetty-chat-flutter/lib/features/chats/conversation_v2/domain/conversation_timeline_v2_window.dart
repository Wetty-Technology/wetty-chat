import 'package:chahua/features/chats/conversation_v2/domain/conversation_message_v2.dart';

typedef ConversationTimelineV2Window = ({
  List<ConversationMessageV2> beforeMessages,
  List<ConversationMessageV2> afterMessages,
  bool canLoadOlder,
  bool canLoadNewer,
});
