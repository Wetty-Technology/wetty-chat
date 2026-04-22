import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../list/presentation/chat_list_segment.dart';
import '../../../list/application/chat_list_view_model.dart';
import '../../../list/presentation/models/merged_list_item.dart';
import '../../../threads/application/thread_list_view_model.dart';
import '../../../threads/presentation/thread_list_view.dart';
import '../group_list_v2_view.dart';

class ChatListV2TabBody extends ConsumerWidget {
  const ChatListV2TabBody({
    super.key,
    required this.activeTab,
    required this.chatAsync,
    required this.threadAsync,
    required this.mergedItems,
    required this.scrollController,
    required this.supportsPullToRefresh,
  });

  final ChatListTab activeTab;
  final AsyncValue<ChatListViewState> chatAsync;
  final AsyncValue<ThreadListViewState> threadAsync;
  final List<MergedListItem> mergedItems;
  final ScrollController scrollController;
  final bool supportsPullToRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (activeTab) {
      ChatListTab.groups => GroupListV2View(
        scrollController: scrollController,
        supportsPullToRefresh: supportsPullToRefresh,
      ),
      ChatListTab.threads => const ThreadListView(embedded: true),
      ChatListTab.all => _V2PlaceholderBody(
        message:
            'The All tab still uses the old merged flow. We will move it to list_v2 later.',
      ),
    };
  }
}

class _V2PlaceholderBody extends StatelessWidget {
  const _V2PlaceholderBody({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
