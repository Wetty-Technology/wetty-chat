import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chahua/core/api/models/current_user_api_models.dart';
import 'package:chahua/core/api/services/current_user_api_service.dart';
import 'package:chahua/core/session/dev_session_store.dart';

class CurrentUserProfile {
  const CurrentUserProfile({
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

  factory CurrentUserProfile.fromDto(CurrentUserDto dto) {
    return CurrentUserProfile(
      uid: dto.uid,
      username: dto.username,
      avatarUrl: dto.avatarUrl,
      gender: dto.gender,
      permissions: dto.permissions,
    );
  }
}

final currentUserProfileProvider = FutureProvider<CurrentUserProfile?>((
  ref,
) async {
  final session = ref.watch(authSessionProvider);
  if (!session.isAuthenticated) {
    return null;
  }

  final api = ref.watch(currentUserApiServiceProvider);
  final dto = await api.fetchMe();
  return CurrentUserProfile.fromDto(dto);
});
