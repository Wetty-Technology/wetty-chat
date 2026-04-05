import 'package:json_annotation/json_annotation.dart';

class NullableDateTimeConverter implements JsonConverter<DateTime?, Object?> {
  const NullableDateTimeConverter();

  @override
  DateTime? fromJson(Object? json) {
    if (json == null) return null;
    if (json is DateTime) return json;

    final value = json.toString().trim();
    if (value.isEmpty) return null;

    return DateTime.parse(value);
  }

  @override
  Object? toJson(DateTime? object) => object?.toIso8601String();
}
