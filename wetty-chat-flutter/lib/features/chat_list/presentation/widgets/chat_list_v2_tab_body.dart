import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../all_list_v2_view.dart';
import '../group_list_v2_view.dart';
import '../thread_list_v2_view.dart';
import 'chat_list_segment.dart';

class ChatListV2TabBody extends ConsumerWidget {
  const ChatListV2TabBody({super.key, required this.activeTab});

  final ChatListTab activeTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (activeTab) {
      ChatListTab.groups => const GroupListV2View(),
      ChatListTab.threads => const ThreadListV2View(),
      ChatListTab.all => const AllListV2View(),
    };
  }
}
