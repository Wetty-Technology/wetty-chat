import '../../features/auth/application/auth_store.dart';

const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://chahui.app/_api',
);

class ApiSession {
  const ApiSession._();

  static int? get currentUserId => AuthStore.instance.currentUserId;
  static String? get token => AuthStore.instance.token;
}

Map<String, String> get apiHeaders {
  final headers = <String, String>{
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  final token = ApiSession.token;
  if (token != null) {
    headers['Authorization'] = 'Bearer $token';
  }

  final uid = ApiSession.currentUserId;
  // TODO: for development test only. Remove in production.
  if (uid != null) {
    headers['X-User-Id'] = uid.toString();
    headers['X-Client-Id'] = uid.toString();
  }

  return headers;
}
