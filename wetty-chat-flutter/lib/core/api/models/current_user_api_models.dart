class CurrentUserDto {
  const CurrentUserDto({
    required this.uid,
    required this.username,
    this.avatarUrl,
    this.gender = 0,
    this.permissions = const <String>[],
  });

  final int uid;
  final String username;
  final String? avatarUrl;
  final int gender;
  final List<String> permissions;

  factory CurrentUserDto.fromJson(Map<String, dynamic> json) {
    return CurrentUserDto(
      uid: json['uid'] as int,
      username: json['username'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      gender: json['gender'] as int? ?? 0,
      permissions:
          (json['permissions'] as List<dynamic>?)?.whereType<String>().toList(
            growable: false,
          ) ??
          const <String>[],
    );
  }
}
