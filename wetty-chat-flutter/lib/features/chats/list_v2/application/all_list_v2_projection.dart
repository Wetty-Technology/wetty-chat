import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'all_list_v2_models.dart';
import 'group_list_v2_store.dart';
import 'thread_list_v2_store.dart';

final allListV2ItemsProvider = Provider<List<AllListV2Item>>((ref) {
  final groups = ref.watch(
    groupListV2StoreProvider.select((state) => state.groups),
  );
  final threads = ref.watch(
    threadListV2StoreProvider.select((state) => state.threads),
  );

  final items = <AllListV2Item>[
    for (final group in groups) AllGroupListV2Item(group),
    for (final thread in threads) AllThreadListV2Item(thread),
  ];

  items.sort((a, b) {
    final aTime = a.activityAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bTime = b.activityAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bTime.compareTo(aTime);
  });

  return List<AllListV2Item>.unmodifiable(items);
});
