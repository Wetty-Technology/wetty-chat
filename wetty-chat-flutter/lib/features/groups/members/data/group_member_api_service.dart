import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/network/api_config.dart';
import 'group_member_models.dart';

class GroupMemberApiService {
  Future<List<GroupMember>> fetchMembers(String chatId) async {
    final uri = Uri.parse('$apiBaseUrl/group/$chatId/members');
    final response = await http.get(uri, headers: apiHeaders);
    if (response.statusCode != 200) {
      throw Exception('Failed to load members: ${response.statusCode}');
    }

    final body = jsonDecode(response.body);
    final list = body is List
        ? body
        : (body['members'] as List<dynamic>? ?? []);
    return list
        .map((entry) => GroupMember.fromJson(entry as Map<String, dynamic>))
        .toList(growable: false);
  }
}
