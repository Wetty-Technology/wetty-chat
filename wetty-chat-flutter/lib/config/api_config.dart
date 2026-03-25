import 'auth_store.dart';

const String apiBaseUrl = 'https://chahui.app/_api';

int? get curUserId => AuthStore.instance.currentUserId;

Map<String, String> get apiHeaders {
  final headers = <String, String>{
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  final token = AuthStore.instance.token;
  if (token != null) {
    headers['Authorization'] = 'Bearer $token';
  }

  final uid = curUserId;
  if (uid != null) {
    headers['X-User-Id'] = uid.toString();
  }

  return headers;
}
