import 'package:json_annotation/json_annotation.dart';

class StringValueConverter implements JsonConverter<String, Object?> {
  const StringValueConverter();

  @override
  String fromJson(Object? json) => json?.toString() ?? '';

  @override
  Object toJson(String object) => object;
}
