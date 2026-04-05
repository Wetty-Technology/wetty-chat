const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://chahui.app/_api',
);

/// Build API headers for a specific user ID.
Map<String, String> apiHeadersForUser(int userId) {
  return <String, String>{
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'X-User-Id': userId.toString(),
    'X-Client-Id': userId.toString(),
  };
}

/// Thin bridge for presentation-layer code that cannot access Riverpod ref
/// (e.g., image loading headers in deeply nested widgets).
/// Kept in sync with [devSessionProvider] via the app widget.
class ApiSession {
  const ApiSession._();

  static int _currentUserId = 1;
  static int get currentUserId => _currentUserId;

  static void updateUserId(int userId) {
    _currentUserId = userId;
  }
}
