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
  final DateTime? joinedAt;
}
