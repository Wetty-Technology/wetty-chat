import 'package:json_annotation/json_annotation.dart';

class FlexibleIntConverter implements JsonConverter<int, Object?> {
  const FlexibleIntConverter();

  @override
  int fromJson(Object? json) {
    if (json is int) return json;
    if (json is String) return int.parse(json);
    if (json == null) return 0;
    throw FormatException('Invalid integer value: $json');
  }

  @override
  Object toJson(int object) => object;
}

class NullableFlexibleIntConverter implements JsonConverter<int?, Object?> {
  const NullableFlexibleIntConverter();

  @override
  int? fromJson(Object? json) {
    if (json == null) return null;
    return const FlexibleIntConverter().fromJson(json);
  }

  @override
  Object? toJson(int? object) => object;
}
