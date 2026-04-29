import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'all_list_v2_models.dart';
import 'group_list_v2_store.dart';
import 'thread_list_v2_store.dart';

final allListV2ItemsProvider = Provider<List<AllListV2Item>>((ref) {
  final groups = ref.watch(
    groupListV2StoreProvider.select((state) => state.groups),
  );
  final threads = ref.watch(
    threadListV2StoreProvider.select((state) => state.active.threads),
  );

  final items = <AllListV2Item>[];
  var groupIndex = 0;
  var threadIndex = 0;

  while (groupIndex < groups.length && threadIndex < threads.length) {
    final groupItem = AllGroupListV2Item(groups[groupIndex]);
    final threadItem = AllThreadListV2Item(threads[threadIndex]);
    final groupTime =
        groupItem.activityAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final threadTime =
        threadItem.activityAt ?? DateTime.fromMillisecondsSinceEpoch(0);

    if (!groupTime.isBefore(threadTime)) {
      items.add(groupItem);
      groupIndex += 1;
      continue;
    }

    items.add(threadItem);
    threadIndex += 1;
  }

  while (groupIndex < groups.length) {
    items.add(AllGroupListV2Item(groups[groupIndex]));
    groupIndex += 1;
  }

  while (threadIndex < threads.length) {
    items.add(AllThreadListV2Item(threads[threadIndex]));
    threadIndex += 1;
  }

  return List<AllListV2Item>.unmodifiable(items);
});
