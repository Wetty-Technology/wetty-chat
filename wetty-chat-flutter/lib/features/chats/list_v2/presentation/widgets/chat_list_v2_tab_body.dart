import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../list/presentation/chat_list_segment.dart';
import '../all_list_v2_view.dart';
import '../group_list_v2_view.dart';
import '../thread_list_v2_view.dart';

class ChatListV2TabBody extends ConsumerWidget {
  const ChatListV2TabBody({
    super.key,
    required this.activeTab,
    required this.scrollController,
    required this.supportsPullToRefresh,
  });

  final ChatListTab activeTab;
  final ScrollController scrollController;
  final bool supportsPullToRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (activeTab) {
      ChatListTab.groups => GroupListV2View(
        scrollController: scrollController,
        supportsPullToRefresh: supportsPullToRefresh,
      ),
      ChatListTab.threads => ThreadListV2View(
        scrollController: scrollController,
        supportsPullToRefresh: supportsPullToRefresh,
      ),
      ChatListTab.all => AllListV2View(
        scrollController: scrollController,
        supportsPullToRefresh: supportsPullToRefresh,
      ),
    };
  }
}
