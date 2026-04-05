import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../../core/api/client/api_json.dart';
import '../../../../core/api/models/group_members_api_models.dart';
import '../../../../core/network/api_config.dart';
import '../../../../core/session/dev_session_store.dart';

class GroupMemberApiService {
  final int _userId;

  GroupMemberApiService(this._userId);

  Map<String, String> get _headers => apiHeadersForUser(_userId);

  Future<GroupMembersResponseDto> fetchMembers(String chatId) async {
    final uri = Uri.parse('$apiBaseUrl/group/$chatId/members');
    final response = await http.get(uri, headers: _headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to load members: ${response.statusCode}');
    }

    return GroupMembersResponseDto.fromJson(decodeJsonObject(response.body));
  }
}

final groupMemberApiServiceProvider = Provider<GroupMemberApiService>((ref) {
  final userId = ref.watch(devSessionProvider);
  return GroupMemberApiService(userId);
});
