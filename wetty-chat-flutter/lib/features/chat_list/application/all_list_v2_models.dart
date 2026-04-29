import '../model/chat_list_item.dart';
import '../model/thread_list_item.dart';

sealed class AllListV2Item {
  DateTime? get activityAt;
}

class AllGroupListV2Item extends AllListV2Item {
  AllGroupListV2Item(this.group);

  final ChatListItem group;

  @override
  DateTime? get activityAt => group.lastMessageAt;
}

class AllThreadListV2Item extends AllListV2Item {
  AllThreadListV2Item(this.thread);

  final ThreadListItem thread;

  @override
  DateTime? get activityAt => thread.lastReplyAt;
}
