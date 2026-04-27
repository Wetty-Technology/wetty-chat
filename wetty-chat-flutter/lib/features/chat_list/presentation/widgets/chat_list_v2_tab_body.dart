import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../all_list_v2_view.dart';
import '../group_list_v2_view.dart';
import '../thread_list_v2_view.dart';
import 'chat_list_segment.dart';

class ChatListV2TabBody extends ConsumerWidget {
  const ChatListV2TabBody({
    super.key,
    required this.activeTab,
    this.selectedChatId,
    this.selectedThreadRootId,
  });

  final ChatListTab activeTab;
  final String? selectedChatId;
  final int? selectedThreadRootId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (activeTab) {
      ChatListTab.groups => GroupListV2View(
        selectedChatId: selectedThreadRootId == null ? selectedChatId : null,
      ),
      ChatListTab.threads => ThreadListV2View(
        selectedThreadRootId: selectedThreadRootId,
      ),
      ChatListTab.all => AllListV2View(
        selectedChatId: selectedThreadRootId == null ? selectedChatId : null,
        selectedThreadRootId: selectedThreadRootId,
      ),
    };
  }
}
