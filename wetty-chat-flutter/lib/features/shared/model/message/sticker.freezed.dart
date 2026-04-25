// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sticker.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StickerMedia {

 String get id; String get url; String get contentType; int get size; int? get width; int? get height;
/// Create a copy of StickerMedia
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StickerMediaCopyWith<StickerMedia> get copyWith => _$StickerMediaCopyWithImpl<StickerMedia>(this as StickerMedia, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StickerMedia&&(identical(other.id, id) || other.id == id)&&(identical(other.url, url) || other.url == url)&&(identical(other.contentType, contentType) || other.contentType == contentType)&&(identical(other.size, size) || other.size == size)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height));
}


@override
int get hashCode => Object.hash(runtimeType,id,url,contentType,size,width,height);

@override
String toString() {
  return 'StickerMedia(id: $id, url: $url, contentType: $contentType, size: $size, width: $width, height: $height)';
}


}

/// @nodoc
abstract mixin class $StickerMediaCopyWith<$Res>  {
  factory $StickerMediaCopyWith(StickerMedia value, $Res Function(StickerMedia) _then) = _$StickerMediaCopyWithImpl;
@useResult
$Res call({
 String id, String url, String contentType, int size, int? width, int? height
});




}
/// @nodoc
class _$StickerMediaCopyWithImpl<$Res>
    implements $StickerMediaCopyWith<$Res> {
  _$StickerMediaCopyWithImpl(this._self, this._then);

  final StickerMedia _self;
  final $Res Function(StickerMedia) _then;

/// Create a copy of StickerMedia
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? url = null,Object? contentType = null,Object? size = null,Object? width = freezed,Object? height = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,contentType: null == contentType ? _self.contentType : contentType // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,width: freezed == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int?,height: freezed == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [StickerMedia].
extension StickerMediaPatterns on StickerMedia {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StickerMedia value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StickerMedia() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StickerMedia value)  $default,){
final _that = this;
switch (_that) {
case _StickerMedia():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StickerMedia value)?  $default,){
final _that = this;
switch (_that) {
case _StickerMedia() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String url,  String contentType,  int size,  int? width,  int? height)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StickerMedia() when $default != null:
return $default(_that.id,_that.url,_that.contentType,_that.size,_that.width,_that.height);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String url,  String contentType,  int size,  int? width,  int? height)  $default,) {final _that = this;
switch (_that) {
case _StickerMedia():
return $default(_that.id,_that.url,_that.contentType,_that.size,_that.width,_that.height);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String url,  String contentType,  int size,  int? width,  int? height)?  $default,) {final _that = this;
switch (_that) {
case _StickerMedia() when $default != null:
return $default(_that.id,_that.url,_that.contentType,_that.size,_that.width,_that.height);case _:
  return null;

}
}

}

/// @nodoc


class _StickerMedia extends StickerMedia {
  const _StickerMedia({required this.id, required this.url, required this.contentType, required this.size, this.width, this.height}): super._();
  

@override final  String id;
@override final  String url;
@override final  String contentType;
@override final  int size;
@override final  int? width;
@override final  int? height;

/// Create a copy of StickerMedia
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StickerMediaCopyWith<_StickerMedia> get copyWith => __$StickerMediaCopyWithImpl<_StickerMedia>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StickerMedia&&(identical(other.id, id) || other.id == id)&&(identical(other.url, url) || other.url == url)&&(identical(other.contentType, contentType) || other.contentType == contentType)&&(identical(other.size, size) || other.size == size)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height));
}


@override
int get hashCode => Object.hash(runtimeType,id,url,contentType,size,width,height);

@override
String toString() {
  return 'StickerMedia(id: $id, url: $url, contentType: $contentType, size: $size, width: $width, height: $height)';
}


}

/// @nodoc
abstract mixin class _$StickerMediaCopyWith<$Res> implements $StickerMediaCopyWith<$Res> {
  factory _$StickerMediaCopyWith(_StickerMedia value, $Res Function(_StickerMedia) _then) = __$StickerMediaCopyWithImpl;
@override @useResult
$Res call({
 String id, String url, String contentType, int size, int? width, int? height
});




}
/// @nodoc
class __$StickerMediaCopyWithImpl<$Res>
    implements _$StickerMediaCopyWith<$Res> {
  __$StickerMediaCopyWithImpl(this._self, this._then);

  final _StickerMedia _self;
  final $Res Function(_StickerMedia) _then;

/// Create a copy of StickerMedia
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? url = null,Object? contentType = null,Object? size = null,Object? width = freezed,Object? height = freezed,}) {
  return _then(_StickerMedia(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,contentType: null == contentType ? _self.contentType : contentType // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,width: freezed == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int?,height: freezed == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
mixin _$StickerSummary {

 String get id; StickerMedia? get media; String? get emoji; String? get name; String? get description; DateTime? get createdAt; bool? get isFavorited;
/// Create a copy of StickerSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StickerSummaryCopyWith<StickerSummary> get copyWith => _$StickerSummaryCopyWithImpl<StickerSummary>(this as StickerSummary, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StickerSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.media, media) || other.media == media)&&(identical(other.emoji, emoji) || other.emoji == emoji)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.isFavorited, isFavorited) || other.isFavorited == isFavorited));
}


@override
int get hashCode => Object.hash(runtimeType,id,media,emoji,name,description,createdAt,isFavorited);

@override
String toString() {
  return 'StickerSummary(id: $id, media: $media, emoji: $emoji, name: $name, description: $description, createdAt: $createdAt, isFavorited: $isFavorited)';
}


}

/// @nodoc
abstract mixin class $StickerSummaryCopyWith<$Res>  {
  factory $StickerSummaryCopyWith(StickerSummary value, $Res Function(StickerSummary) _then) = _$StickerSummaryCopyWithImpl;
@useResult
$Res call({
 String id, StickerMedia? media, String? emoji, String? name, String? description, DateTime? createdAt, bool? isFavorited
});


$StickerMediaCopyWith<$Res>? get media;

}
/// @nodoc
class _$StickerSummaryCopyWithImpl<$Res>
    implements $StickerSummaryCopyWith<$Res> {
  _$StickerSummaryCopyWithImpl(this._self, this._then);

  final StickerSummary _self;
  final $Res Function(StickerSummary) _then;

/// Create a copy of StickerSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? media = freezed,Object? emoji = freezed,Object? name = freezed,Object? description = freezed,Object? createdAt = freezed,Object? isFavorited = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,media: freezed == media ? _self.media : media // ignore: cast_nullable_to_non_nullable
as StickerMedia?,emoji: freezed == emoji ? _self.emoji : emoji // ignore: cast_nullable_to_non_nullable
as String?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isFavorited: freezed == isFavorited ? _self.isFavorited : isFavorited // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}
/// Create a copy of StickerSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StickerMediaCopyWith<$Res>? get media {
    if (_self.media == null) {
    return null;
  }

  return $StickerMediaCopyWith<$Res>(_self.media!, (value) {
    return _then(_self.copyWith(media: value));
  });
}
}


/// Adds pattern-matching-related methods to [StickerSummary].
extension StickerSummaryPatterns on StickerSummary {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StickerSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StickerSummary() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StickerSummary value)  $default,){
final _that = this;
switch (_that) {
case _StickerSummary():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StickerSummary value)?  $default,){
final _that = this;
switch (_that) {
case _StickerSummary() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  StickerMedia? media,  String? emoji,  String? name,  String? description,  DateTime? createdAt,  bool? isFavorited)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StickerSummary() when $default != null:
return $default(_that.id,_that.media,_that.emoji,_that.name,_that.description,_that.createdAt,_that.isFavorited);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  StickerMedia? media,  String? emoji,  String? name,  String? description,  DateTime? createdAt,  bool? isFavorited)  $default,) {final _that = this;
switch (_that) {
case _StickerSummary():
return $default(_that.id,_that.media,_that.emoji,_that.name,_that.description,_that.createdAt,_that.isFavorited);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  StickerMedia? media,  String? emoji,  String? name,  String? description,  DateTime? createdAt,  bool? isFavorited)?  $default,) {final _that = this;
switch (_that) {
case _StickerSummary() when $default != null:
return $default(_that.id,_that.media,_that.emoji,_that.name,_that.description,_that.createdAt,_that.isFavorited);case _:
  return null;

}
}

}

/// @nodoc


class _StickerSummary implements StickerSummary {
  const _StickerSummary({required this.id, this.media, this.emoji, this.name, this.description, this.createdAt, this.isFavorited});
  

@override final  String id;
@override final  StickerMedia? media;
@override final  String? emoji;
@override final  String? name;
@override final  String? description;
@override final  DateTime? createdAt;
@override final  bool? isFavorited;

/// Create a copy of StickerSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StickerSummaryCopyWith<_StickerSummary> get copyWith => __$StickerSummaryCopyWithImpl<_StickerSummary>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StickerSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.media, media) || other.media == media)&&(identical(other.emoji, emoji) || other.emoji == emoji)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.isFavorited, isFavorited) || other.isFavorited == isFavorited));
}


@override
int get hashCode => Object.hash(runtimeType,id,media,emoji,name,description,createdAt,isFavorited);

@override
String toString() {
  return 'StickerSummary(id: $id, media: $media, emoji: $emoji, name: $name, description: $description, createdAt: $createdAt, isFavorited: $isFavorited)';
}


}

/// @nodoc
abstract mixin class _$StickerSummaryCopyWith<$Res> implements $StickerSummaryCopyWith<$Res> {
  factory _$StickerSummaryCopyWith(_StickerSummary value, $Res Function(_StickerSummary) _then) = __$StickerSummaryCopyWithImpl;
@override @useResult
$Res call({
 String id, StickerMedia? media, String? emoji, String? name, String? description, DateTime? createdAt, bool? isFavorited
});


@override $StickerMediaCopyWith<$Res>? get media;

}
/// @nodoc
class __$StickerSummaryCopyWithImpl<$Res>
    implements _$StickerSummaryCopyWith<$Res> {
  __$StickerSummaryCopyWithImpl(this._self, this._then);

  final _StickerSummary _self;
  final $Res Function(_StickerSummary) _then;

/// Create a copy of StickerSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? media = freezed,Object? emoji = freezed,Object? name = freezed,Object? description = freezed,Object? createdAt = freezed,Object? isFavorited = freezed,}) {
  return _then(_StickerSummary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,media: freezed == media ? _self.media : media // ignore: cast_nullable_to_non_nullable
as StickerMedia?,emoji: freezed == emoji ? _self.emoji : emoji // ignore: cast_nullable_to_non_nullable
as String?,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isFavorited: freezed == isFavorited ? _self.isFavorited : isFavorited // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

/// Create a copy of StickerSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StickerMediaCopyWith<$Res>? get media {
    if (_self.media == null) {
    return null;
  }

  return $StickerMediaCopyWith<$Res>(_self.media!, (value) {
    return _then(_self.copyWith(media: value));
  });
}
}

// dart format on
