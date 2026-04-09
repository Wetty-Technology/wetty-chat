import '../../../models/chat_models.dart';
import '../../../threads/models/thread_models.dart';

sealed class MergedListItem {
  DateTime? get sortTime;
}

class MergedChatItem extends MergedListItem {
  MergedChatItem(this.chat);

  final ChatListItem chat;

  @override
  DateTime? get sortTime => chat.lastMessageAt;
}

class MergedThreadItem extends MergedListItem {
  MergedThreadItem(this.thread);

  final ThreadListItem thread;

  @override
  DateTime? get sortTime => thread.lastReplyAt;
}

List<MergedListItem> buildMergedList(
  List<ChatListItem> chats,
  List<ThreadListItem> threads,
) {
  final items = <MergedListItem>[
    for (final chat in chats) MergedChatItem(chat),
    for (final thread in threads) MergedThreadItem(thread),
  ];
  items.sort((a, b) {
    final aTime = a.sortTime ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bTime = b.sortTime ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bTime.compareTo(aTime);
  });
  return items;
}
