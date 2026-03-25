// Shared API config.
// TODO: replace with actual auth when available.
const int curUserId = 1;
const String apiBaseUrl = 'https://wchat.i386.mov/_api';
Map<String, String> get apiHeaders => {
  'Content-Type': 'application/json',
  'Accept': 'application/json',
  'X-User-Id': curUserId.toString(),
};
