import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chahua/core/api/models/current_user_api_models.dart';
import 'package:chahua/core/api/services/current_user_api_service.dart';
import 'package:chahua/core/session/current_user_profile.dart';
import 'package:chahua/core/session/dev_session_store.dart';

void main() {
  test('loads the current user profile when authenticated', () async {
    final api = _FakeCurrentUserApiService(
      response: const CurrentUserDto(
        uid: 42,
        username: 'Alice',
        avatarUrl: 'https://example.com/alice.png',
        gender: 1,
        permissions: <String>['admin'],
      ),
    );
    final container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(_AuthenticatedSessionNotifier.new),
        currentUserApiServiceProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);

    final profile = await container.read(currentUserProfileProvider.future);

    expect(api.fetchCount, 1);
    expect(profile?.uid, 42);
    expect(profile?.username, 'Alice');
    expect(profile?.avatarUrl, 'https://example.com/alice.png');
    expect(profile?.permissions, <String>['admin']);
  });

  test('does not fetch a profile when unauthenticated', () async {
    final api = _FakeCurrentUserApiService(
      response: const CurrentUserDto(uid: 42, username: 'Alice'),
    );
    final container = ProviderContainer(
      overrides: [
        authSessionProvider.overrideWith(_UnauthenticatedSessionNotifier.new),
        currentUserApiServiceProvider.overrideWithValue(api),
      ],
    );
    addTearDown(container.dispose);

    final profile = await container.read(currentUserProfileProvider.future);

    expect(profile, isNull);
    expect(api.fetchCount, 0);
  });
}

class _AuthenticatedSessionNotifier extends AuthSessionNotifier {
  @override
  AuthSessionState build() {
    return const AuthSessionState(
      status: AuthBootstrapStatus.authenticated,
      mode: AuthSessionMode.devHeader,
      developerUserId: 42,
      currentUserId: 42,
    );
  }
}

class _UnauthenticatedSessionNotifier extends AuthSessionNotifier {
  @override
  AuthSessionState build() {
    return const AuthSessionState(
      status: AuthBootstrapStatus.unauthenticated,
      mode: AuthSessionMode.none,
      developerUserId: 1,
      currentUserId: 1,
    );
  }
}

class _FakeCurrentUserApiService extends CurrentUserApiService {
  _FakeCurrentUserApiService({required this.response}) : super(Dio());

  final CurrentUserDto response;
  int fetchCount = 0;

  @override
  Future<CurrentUserDto> fetchMe() async {
    fetchCount += 1;
    return response;
  }
}
