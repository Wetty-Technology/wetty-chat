import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/chat_models.dart';
import '../../models/message_models.dart';

typedef GroupListV2StoreState = ({List<ChatListItem> groups});

class GroupListV2Store extends Notifier<GroupListV2StoreState> {
  @override
  GroupListV2StoreState build() {
    return (groups: _fakeGroups);
  }
}

final groupListV2StoreProvider =
    NotifierProvider<GroupListV2Store, GroupListV2StoreState>(
      GroupListV2Store.new,
    );

final List<ChatListItem> _fakeGroups = <ChatListItem>[
  ChatListItem(
    id: 'v2-group-design',
    name: 'Design Crit',
    avatarUrl: null,
    lastMessageAt: DateTime.utc(2026, 4, 20, 18, 42),
    unreadCount: 3,
    lastReadMessageId: '9001001',
    lastMessage: MessageItem(
      id: 9001004,
      message: 'Uploaded the revised mockups for the composer states.',
      messageType: 'text',
      sender: Sender(uid: 101, name: 'Mia'),
      chatId: 'v2-group-design',
      createdAt: DateTime.utc(2026, 4, 20, 18, 42),
    ),
  ),
  ChatListItem(
    id: 'v2-group-mobile',
    name: 'Mobile V2',
    avatarUrl: null,
    lastMessageAt: DateTime.utc(2026, 4, 20, 17, 05),
    unreadCount: 0,
    lastReadMessageId: '9002002',
    lastMessage: MessageItem(
      id: 9002002,
      message: 'Let us keep the first cut fake-data only.',
      messageType: 'text',
      sender: Sender(uid: 102, name: 'Evan'),
      chatId: 'v2-group-mobile',
      createdAt: DateTime.utc(2026, 4, 20, 17, 05),
    ),
  ),
  ChatListItem(
    id: 'v2-group-eng',
    name: 'Engineering',
    avatarUrl: null,
    lastMessageAt: DateTime.utc(2026, 4, 20, 15, 30),
    unreadCount: 1,
    lastReadMessageId: '9003000',
    lastMessage: MessageItem(
      id: 9003001,
      message: 'Backend deploy is done. Monitoring for regressions now.',
      messageType: 'text',
      sender: Sender(uid: 103, name: 'Noah'),
      chatId: 'v2-group-eng',
      createdAt: DateTime.utc(2026, 4, 20, 15, 30),
    ),
  ),
];
