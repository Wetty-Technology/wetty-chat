import 'package:json_annotation/json_annotation.dart';

class StringMapConverter
    implements JsonConverter<Map<String, String>, Map<String, dynamic>?> {
  const StringMapConverter();

  @override
  Map<String, String> fromJson(Map<String, dynamic>? json) {
    if (json == null) return const {};
    return json.map((key, value) => MapEntry(key, value.toString()));
  }

  @override
  Map<String, dynamic> toJson(Map<String, String> object) => object;
}
