import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/chat_models.dart';
import 'group_list_v2_store.dart';

final groupListV2ProjectionProvider = Provider<List<ChatListItem>>((ref) {
  final groups = ref.watch(
    groupListV2StoreProvider.select((state) => state.groups),
  );
  return List<ChatListItem>.unmodifiable(groups);
});
