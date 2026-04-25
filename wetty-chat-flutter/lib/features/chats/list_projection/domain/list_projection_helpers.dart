import '../../../../core/api/models/messages_api_models.dart';
import '../../../chat_list_v2/model/chat_list_item.dart';
import 'package:chahua/features/shared/model/message/message.dart';
import '../../threads/models/thread_models.dart';

bool isEligibleChatPreviewMessage(MessageItem message) {
  return message.replyRootId == null && !message.isDeleted;
}

bool isEligibleThreadPreviewPayload(MessageItemDto payload) {
  return payload.replyRootId != null && !payload.isDeleted;
}

bool matchesChatPreview(MessageItem? preview, MessageItemDto payload) {
  if (preview == null) {
    return false;
  }
  if (preview.id == payload.id) {
    return true;
  }
  return preview.clientGeneratedId.isNotEmpty &&
      preview.clientGeneratedId == payload.clientGeneratedId;
}

bool matchesThreadPreview(MessagePreview? preview, MessageItemDto payload) {
  if (preview == null) {
    return false;
  }
  if (preview.messageId != null) {
    return preview.messageId == payload.id;
  }
  final clientGeneratedId = preview.clientGeneratedId;
  return clientGeneratedId != null &&
      clientGeneratedId.isNotEmpty &&
      clientGeneratedId == payload.clientGeneratedId;
}

List<ChatListItem> replaceChatAt(
  List<ChatListItem> chats,
  int index,
  ChatListItem updated,
) {
  final next = [...chats];
  next[index] = updated;
  return next;
}

List<ThreadListItem> replaceThreadAt(
  List<ThreadListItem> threads,
  int index,
  ThreadListItem updated,
) {
  final next = [...threads];
  next[index] = updated;
  return next;
}

List<ChatListItem> moveChatToFront(
  List<ChatListItem> chats,
  int index,
  ChatListItem updated,
) {
  final next = [...chats]..removeAt(index);
  next.insert(0, updated);
  return next;
}

List<ThreadListItem> reinsertThreadByActivity(
  List<ThreadListItem> threads,
  int index,
  ThreadListItem updated,
) {
  final updatedActivity = updated.lastReplyAt;
  final next = [...threads]..removeAt(index);
  if (updatedActivity == null) {
    next.add(updated);
    return next;
  }

  final insertAt = next.indexWhere((candidate) {
    final candidateActivity = candidate.lastReplyAt;
    if (candidateActivity == null) {
      return true;
    }
    return updatedActivity.isAfter(candidateActivity);
  });
  if (insertAt < 0) {
    next.add(updated);
  } else {
    next.insert(insertAt, updated);
  }
  return next;
}
