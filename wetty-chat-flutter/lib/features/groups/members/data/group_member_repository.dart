import 'group_member_api_mapper.dart';
import 'group_member_api_service.dart';
import 'group_member_models.dart';

class GroupMemberRepository {
  GroupMemberRepository({GroupMemberApiService? apiService})
    : _apiService = apiService ?? GroupMemberApiService();

  final GroupMemberApiService _apiService;

  Future<List<GroupMember>> fetchMembers(String chatId) async {
    final response = await _apiService.fetchMembers(chatId);
    return response.members.map((member) => member.toDomain()).toList();
  }
}
