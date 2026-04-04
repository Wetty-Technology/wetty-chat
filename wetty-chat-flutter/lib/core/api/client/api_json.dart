import 'dart:convert';

T decodeJsonObject<T>(
  String body, [
  T Function(Map<String, dynamic> json)? fromJson,
]) {
  final decoded = jsonDecode(body);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Expected a JSON object');
  }
  if (fromJson != null) {
    return fromJson(decoded);
  }
  return decoded as T;
}

List<dynamic> decodeJsonList(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! List<dynamic>) {
    throw const FormatException('Expected a JSON array.');
  }
  return decoded;
}
