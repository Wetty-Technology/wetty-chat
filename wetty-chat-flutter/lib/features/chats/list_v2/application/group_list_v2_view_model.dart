import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/chat_models.dart';
import 'group_list_v2_projection.dart';

typedef GroupListV2ViewState = ({
  List<ChatListItem> groups,
  bool isLoading,
  String? errorMessage,
});

final groupListV2ViewModelProvider = Provider<GroupListV2ViewState>((ref) {
  final groups = ref.watch(groupListV2ProjectionProvider);
  return (groups: groups, isLoading: false, errorMessage: null);
});
