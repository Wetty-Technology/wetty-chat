// Shared API config.
// TODO: replace with actual auth when available.
const int curUserId = 1;
const String apiBaseUrl = 'http://10.42.3.100:3000';
Map<String, String> get apiHeaders => {
  'Content-Type': 'application/json',
  'Accept': 'application/json',
  'X-User-Id': curUserId.toString(),
  'X-Client-Id': '1jjj',
};
