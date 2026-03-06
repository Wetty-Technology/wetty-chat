// Shared API config to avoid circular imports (main, chats, messages).
const String apiBaseUrl = 'http://10.42.3.100:3000';
Map<String, String> get apiHeaders => {
  'Content-Type': 'application/json',
  'Accept': 'application/json',
  'X-User-Id': '1',
};
