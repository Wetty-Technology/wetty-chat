import 'package:flutter/cupertino.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'api_config.dart';

/// Model for a group member returned by GET /group/{id}/members.
class _Member {
  final int uid;
  final String? username;
  final String role;
  final String joinedAt;

  _Member({
    required this.uid,
    this.username,
    required this.role,
    required this.joinedAt,
  });

  factory _Member.fromJson(Map<String, dynamic> json) {
    return _Member(
      uid: json['uid'] as int? ?? 0,
      username: json['username'] as String?,
      role: json['role'] as String? ?? 'member',
      joinedAt: json['joined_at'] as String? ?? '',
    );
  }
}

/// Page to display current group members and an "Add Member" button.
class GroupMembersPage extends StatefulWidget {
  const GroupMembersPage({super.key, required this.chatId});
  final String chatId;

  @override
  State<GroupMembersPage> createState() => _GroupMembersPageState();
}

class _GroupMembersPageState extends State<GroupMembersPage> {
  List<_Member> _members = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final uri = Uri.parse('$apiBaseUrl/group/${widget.chatId}/members');
      final response = await http.get(uri, headers: apiHeaders);
      print("res: ${response.body}");
      if (response.statusCode != 200) {
        throw Exception('Failed to load members: ${response.statusCode}');
      }
      final dynamic body = jsonDecode(response.body);
      final list = body is List ? body : (body['members'] as List<dynamic>? ?? []);
      if (!mounted) return;
      setState(() {
        _members = list
            .map((e) => _Member.fromJson(e as Map<String, dynamic>))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Group Members'),
      ),
      child: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CupertinoActivityIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              CupertinoButton.filled(
                onPressed: _loadMembers,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        Expanded(
          child: _members.isEmpty
              ? const Center(child: Text('No members'))
              : ListView.builder(
                  itemCount: _members.length,
                  itemBuilder: (context, index) {
                    final member = _members[index];
                    final name = member.username ?? 'User ${member.uid}';
                    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
                    final isAdmin = member.role.toLowerCase() == 'admin';
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: CupertinoColors.systemGrey4,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              initial,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: CupertinoColors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: const TextStyle(fontSize: 16)),
                                Text(
                                  member.role,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isAdmin
                                        ? CupertinoColors.activeBlue
                                        : CupertinoColors.secondaryLabel,
                                    fontWeight: isAdmin ? FontWeight.w600 : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        // Add Member button
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: CupertinoButton.filled(
              onPressed: () {
                // TODO: implement add member
              },
              child: const Text('Add Member'),
            ),
          ),
        ),
      ],
    );
  }
}
