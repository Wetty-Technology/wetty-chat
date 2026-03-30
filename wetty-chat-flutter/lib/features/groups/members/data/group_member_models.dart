class GroupMember {
  const GroupMember({
    required this.uid,
    this.username,
    required this.role,
    required this.joinedAt,
  });

  final int uid;
  final String? username;
  final String role;
  final String joinedAt;

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      uid: json['uid'] as int? ?? 0,
      username: json['username'] as String?,
      role: json['role'] as String? ?? 'member',
      joinedAt: json['joinedAt'] as String? ?? '',
    );
  }
}
