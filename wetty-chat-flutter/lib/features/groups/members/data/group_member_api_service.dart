import 'package:http/http.dart' as http;

import '../../../../core/api/client/api_json.dart';
import '../../../../core/api/models/group_members_api_models.dart';
import '../../../../core/network/api_config.dart';

class GroupMemberApiService {
  Future<GroupMembersResponseDto> fetchMembers(String chatId) async {
    final uri = Uri.parse('$apiBaseUrl/group/$chatId/members');
    final response = await http.get(uri, headers: apiHeaders);
    if (response.statusCode != 200) {
      throw Exception('Failed to load members: ${response.statusCode}');
    }

    return GroupMembersResponseDto.fromJson(decodeJsonObject(response.body));
  }
}
