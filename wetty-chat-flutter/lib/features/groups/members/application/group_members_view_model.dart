import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/group_member_models.dart';
import '../data/group_member_repository.dart';

class GroupMembersViewModel
    extends FamilyAsyncNotifier<List<GroupMember>, String> {
  @override
  Future<List<GroupMember>> build(String chatId) async {
    final repository = ref.read(groupMemberRepositoryProvider);
    return repository.fetchMembers(chatId);
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(groupMemberRepositoryProvider);
      return repository.fetchMembers(arg);
    });
  }
}

final groupMembersViewModelProvider =
    AsyncNotifierProvider.family<
      GroupMembersViewModel,
      List<GroupMember>,
      String
    >(GroupMembersViewModel.new);
