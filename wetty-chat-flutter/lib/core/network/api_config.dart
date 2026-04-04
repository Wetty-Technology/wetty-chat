import '../session/dev_session_store.dart';

const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://chahui.app/_api',
);

class ApiSession {
  const ApiSession._();

  static int get currentUserId => DevSessionStore.instance.currentUserId;
}

Map<String, String> get apiHeaders {
  final headers = <String, String>{
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  final uid = ApiSession.currentUserId;
  headers['X-User-Id'] = uid.toString();
  headers['X-Client-Id'] = uid.toString();

  return headers;
}
