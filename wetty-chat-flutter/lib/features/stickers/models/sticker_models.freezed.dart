// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sticker_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StickerPackPreviewSticker {

 String get id; StickerMedia get media; String get emoji;
/// Create a copy of StickerPackPreviewSticker
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StickerPackPreviewStickerCopyWith<StickerPackPreviewSticker> get copyWith => _$StickerPackPreviewStickerCopyWithImpl<StickerPackPreviewSticker>(this as StickerPackPreviewSticker, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StickerPackPreviewSticker&&(identical(other.id, id) || other.id == id)&&(identical(other.media, media) || other.media == media)&&(identical(other.emoji, emoji) || other.emoji == emoji));
}


@override
int get hashCode => Object.hash(runtimeType,id,media,emoji);

@override
String toString() {
  return 'StickerPackPreviewSticker(id: $id, media: $media, emoji: $emoji)';
}


}

/// @nodoc
abstract mixin class $StickerPackPreviewStickerCopyWith<$Res>  {
  factory $StickerPackPreviewStickerCopyWith(StickerPackPreviewSticker value, $Res Function(StickerPackPreviewSticker) _then) = _$StickerPackPreviewStickerCopyWithImpl;
@useResult
$Res call({
 String id, StickerMedia media, String emoji
});


$StickerMediaCopyWith<$Res> get media;

}
/// @nodoc
class _$StickerPackPreviewStickerCopyWithImpl<$Res>
    implements $StickerPackPreviewStickerCopyWith<$Res> {
  _$StickerPackPreviewStickerCopyWithImpl(this._self, this._then);

  final StickerPackPreviewSticker _self;
  final $Res Function(StickerPackPreviewSticker) _then;

/// Create a copy of StickerPackPreviewSticker
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? media = null,Object? emoji = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,media: null == media ? _self.media : media // ignore: cast_nullable_to_non_nullable
as StickerMedia,emoji: null == emoji ? _self.emoji : emoji // ignore: cast_nullable_to_non_nullable
as String,
  ));
}
/// Create a copy of StickerPackPreviewSticker
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StickerMediaCopyWith<$Res> get media {
  
  return $StickerMediaCopyWith<$Res>(_self.media, (value) {
    return _then(_self.copyWith(media: value));
  });
}
}


/// Adds pattern-matching-related methods to [StickerPackPreviewSticker].
extension StickerPackPreviewStickerPatterns on StickerPackPreviewSticker {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StickerPackPreviewSticker value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StickerPackPreviewSticker() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StickerPackPreviewSticker value)  $default,){
final _that = this;
switch (_that) {
case _StickerPackPreviewSticker():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StickerPackPreviewSticker value)?  $default,){
final _that = this;
switch (_that) {
case _StickerPackPreviewSticker() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  StickerMedia media,  String emoji)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StickerPackPreviewSticker() when $default != null:
return $default(_that.id,_that.media,_that.emoji);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  StickerMedia media,  String emoji)  $default,) {final _that = this;
switch (_that) {
case _StickerPackPreviewSticker():
return $default(_that.id,_that.media,_that.emoji);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  StickerMedia media,  String emoji)?  $default,) {final _that = this;
switch (_that) {
case _StickerPackPreviewSticker() when $default != null:
return $default(_that.id,_that.media,_that.emoji);case _:
  return null;

}
}

}

/// @nodoc


class _StickerPackPreviewSticker implements StickerPackPreviewSticker {
  const _StickerPackPreviewSticker({required this.id, required this.media, required this.emoji});
  

@override final  String id;
@override final  StickerMedia media;
@override final  String emoji;

/// Create a copy of StickerPackPreviewSticker
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StickerPackPreviewStickerCopyWith<_StickerPackPreviewSticker> get copyWith => __$StickerPackPreviewStickerCopyWithImpl<_StickerPackPreviewSticker>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StickerPackPreviewSticker&&(identical(other.id, id) || other.id == id)&&(identical(other.media, media) || other.media == media)&&(identical(other.emoji, emoji) || other.emoji == emoji));
}


@override
int get hashCode => Object.hash(runtimeType,id,media,emoji);

@override
String toString() {
  return 'StickerPackPreviewSticker(id: $id, media: $media, emoji: $emoji)';
}


}

/// @nodoc
abstract mixin class _$StickerPackPreviewStickerCopyWith<$Res> implements $StickerPackPreviewStickerCopyWith<$Res> {
  factory _$StickerPackPreviewStickerCopyWith(_StickerPackPreviewSticker value, $Res Function(_StickerPackPreviewSticker) _then) = __$StickerPackPreviewStickerCopyWithImpl;
@override @useResult
$Res call({
 String id, StickerMedia media, String emoji
});


@override $StickerMediaCopyWith<$Res> get media;

}
/// @nodoc
class __$StickerPackPreviewStickerCopyWithImpl<$Res>
    implements _$StickerPackPreviewStickerCopyWith<$Res> {
  __$StickerPackPreviewStickerCopyWithImpl(this._self, this._then);

  final _StickerPackPreviewSticker _self;
  final $Res Function(_StickerPackPreviewSticker) _then;

/// Create a copy of StickerPackPreviewSticker
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? media = null,Object? emoji = null,}) {
  return _then(_StickerPackPreviewSticker(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,media: null == media ? _self.media : media // ignore: cast_nullable_to_non_nullable
as StickerMedia,emoji: null == emoji ? _self.emoji : emoji // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

/// Create a copy of StickerPackPreviewSticker
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StickerMediaCopyWith<$Res> get media {
  
  return $StickerMediaCopyWith<$Res>(_self.media, (value) {
    return _then(_self.copyWith(media: value));
  });
}
}

/// @nodoc
mixin _$StickerPackSummary {

 String get id; int get ownerUid; String? get ownerName; String get name; String? get description; DateTime? get createdAt; DateTime? get updatedAt; int get stickerCount; bool get isSubscribed; StickerPackPreviewSticker? get previewSticker;
/// Create a copy of StickerPackSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StickerPackSummaryCopyWith<StickerPackSummary> get copyWith => _$StickerPackSummaryCopyWithImpl<StickerPackSummary>(this as StickerPackSummary, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StickerPackSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.ownerUid, ownerUid) || other.ownerUid == ownerUid)&&(identical(other.ownerName, ownerName) || other.ownerName == ownerName)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.stickerCount, stickerCount) || other.stickerCount == stickerCount)&&(identical(other.isSubscribed, isSubscribed) || other.isSubscribed == isSubscribed)&&(identical(other.previewSticker, previewSticker) || other.previewSticker == previewSticker));
}


@override
int get hashCode => Object.hash(runtimeType,id,ownerUid,ownerName,name,description,createdAt,updatedAt,stickerCount,isSubscribed,previewSticker);

@override
String toString() {
  return 'StickerPackSummary(id: $id, ownerUid: $ownerUid, ownerName: $ownerName, name: $name, description: $description, createdAt: $createdAt, updatedAt: $updatedAt, stickerCount: $stickerCount, isSubscribed: $isSubscribed, previewSticker: $previewSticker)';
}


}

/// @nodoc
abstract mixin class $StickerPackSummaryCopyWith<$Res>  {
  factory $StickerPackSummaryCopyWith(StickerPackSummary value, $Res Function(StickerPackSummary) _then) = _$StickerPackSummaryCopyWithImpl;
@useResult
$Res call({
 String id, int ownerUid, String? ownerName, String name, String? description, DateTime? createdAt, DateTime? updatedAt, int stickerCount, bool isSubscribed, StickerPackPreviewSticker? previewSticker
});


$StickerPackPreviewStickerCopyWith<$Res>? get previewSticker;

}
/// @nodoc
class _$StickerPackSummaryCopyWithImpl<$Res>
    implements $StickerPackSummaryCopyWith<$Res> {
  _$StickerPackSummaryCopyWithImpl(this._self, this._then);

  final StickerPackSummary _self;
  final $Res Function(StickerPackSummary) _then;

/// Create a copy of StickerPackSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? ownerUid = null,Object? ownerName = freezed,Object? name = null,Object? description = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,Object? stickerCount = null,Object? isSubscribed = null,Object? previewSticker = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ownerUid: null == ownerUid ? _self.ownerUid : ownerUid // ignore: cast_nullable_to_non_nullable
as int,ownerName: freezed == ownerName ? _self.ownerName : ownerName // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,stickerCount: null == stickerCount ? _self.stickerCount : stickerCount // ignore: cast_nullable_to_non_nullable
as int,isSubscribed: null == isSubscribed ? _self.isSubscribed : isSubscribed // ignore: cast_nullable_to_non_nullable
as bool,previewSticker: freezed == previewSticker ? _self.previewSticker : previewSticker // ignore: cast_nullable_to_non_nullable
as StickerPackPreviewSticker?,
  ));
}
/// Create a copy of StickerPackSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StickerPackPreviewStickerCopyWith<$Res>? get previewSticker {
    if (_self.previewSticker == null) {
    return null;
  }

  return $StickerPackPreviewStickerCopyWith<$Res>(_self.previewSticker!, (value) {
    return _then(_self.copyWith(previewSticker: value));
  });
}
}


/// Adds pattern-matching-related methods to [StickerPackSummary].
extension StickerPackSummaryPatterns on StickerPackSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StickerPackSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StickerPackSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StickerPackSummary value)  $default,){
final _that = this;
switch (_that) {
case _StickerPackSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StickerPackSummary value)?  $default,){
final _that = this;
switch (_that) {
case _StickerPackSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  int ownerUid,  String? ownerName,  String name,  String? description,  DateTime? createdAt,  DateTime? updatedAt,  int stickerCount,  bool isSubscribed,  StickerPackPreviewSticker? previewSticker)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StickerPackSummary() when $default != null:
return $default(_that.id,_that.ownerUid,_that.ownerName,_that.name,_that.description,_that.createdAt,_that.updatedAt,_that.stickerCount,_that.isSubscribed,_that.previewSticker);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  int ownerUid,  String? ownerName,  String name,  String? description,  DateTime? createdAt,  DateTime? updatedAt,  int stickerCount,  bool isSubscribed,  StickerPackPreviewSticker? previewSticker)  $default,) {final _that = this;
switch (_that) {
case _StickerPackSummary():
return $default(_that.id,_that.ownerUid,_that.ownerName,_that.name,_that.description,_that.createdAt,_that.updatedAt,_that.stickerCount,_that.isSubscribed,_that.previewSticker);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  int ownerUid,  String? ownerName,  String name,  String? description,  DateTime? createdAt,  DateTime? updatedAt,  int stickerCount,  bool isSubscribed,  StickerPackPreviewSticker? previewSticker)?  $default,) {final _that = this;
switch (_that) {
case _StickerPackSummary() when $default != null:
return $default(_that.id,_that.ownerUid,_that.ownerName,_that.name,_that.description,_that.createdAt,_that.updatedAt,_that.stickerCount,_that.isSubscribed,_that.previewSticker);case _:
  return null;

}
}

}

/// @nodoc


class _StickerPackSummary implements StickerPackSummary {
  const _StickerPackSummary({required this.id, required this.ownerUid, this.ownerName, required this.name, this.description, this.createdAt, this.updatedAt, this.stickerCount = 0, this.isSubscribed = false, this.previewSticker});
  

@override final  String id;
@override final  int ownerUid;
@override final  String? ownerName;
@override final  String name;
@override final  String? description;
@override final  DateTime? createdAt;
@override final  DateTime? updatedAt;
@override@JsonKey() final  int stickerCount;
@override@JsonKey() final  bool isSubscribed;
@override final  StickerPackPreviewSticker? previewSticker;

/// Create a copy of StickerPackSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StickerPackSummaryCopyWith<_StickerPackSummary> get copyWith => __$StickerPackSummaryCopyWithImpl<_StickerPackSummary>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StickerPackSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.ownerUid, ownerUid) || other.ownerUid == ownerUid)&&(identical(other.ownerName, ownerName) || other.ownerName == ownerName)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.stickerCount, stickerCount) || other.stickerCount == stickerCount)&&(identical(other.isSubscribed, isSubscribed) || other.isSubscribed == isSubscribed)&&(identical(other.previewSticker, previewSticker) || other.previewSticker == previewSticker));
}


@override
int get hashCode => Object.hash(runtimeType,id,ownerUid,ownerName,name,description,createdAt,updatedAt,stickerCount,isSubscribed,previewSticker);

@override
String toString() {
  return 'StickerPackSummary(id: $id, ownerUid: $ownerUid, ownerName: $ownerName, name: $name, description: $description, createdAt: $createdAt, updatedAt: $updatedAt, stickerCount: $stickerCount, isSubscribed: $isSubscribed, previewSticker: $previewSticker)';
}


}

/// @nodoc
abstract mixin class _$StickerPackSummaryCopyWith<$Res> implements $StickerPackSummaryCopyWith<$Res> {
  factory _$StickerPackSummaryCopyWith(_StickerPackSummary value, $Res Function(_StickerPackSummary) _then) = __$StickerPackSummaryCopyWithImpl;
@override @useResult
$Res call({
 String id, int ownerUid, String? ownerName, String name, String? description, DateTime? createdAt, DateTime? updatedAt, int stickerCount, bool isSubscribed, StickerPackPreviewSticker? previewSticker
});


@override $StickerPackPreviewStickerCopyWith<$Res>? get previewSticker;

}
/// @nodoc
class __$StickerPackSummaryCopyWithImpl<$Res>
    implements _$StickerPackSummaryCopyWith<$Res> {
  __$StickerPackSummaryCopyWithImpl(this._self, this._then);

  final _StickerPackSummary _self;
  final $Res Function(_StickerPackSummary) _then;

/// Create a copy of StickerPackSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? ownerUid = null,Object? ownerName = freezed,Object? name = null,Object? description = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,Object? stickerCount = null,Object? isSubscribed = null,Object? previewSticker = freezed,}) {
  return _then(_StickerPackSummary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ownerUid: null == ownerUid ? _self.ownerUid : ownerUid // ignore: cast_nullable_to_non_nullable
as int,ownerName: freezed == ownerName ? _self.ownerName : ownerName // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,stickerCount: null == stickerCount ? _self.stickerCount : stickerCount // ignore: cast_nullable_to_non_nullable
as int,isSubscribed: null == isSubscribed ? _self.isSubscribed : isSubscribed // ignore: cast_nullable_to_non_nullable
as bool,previewSticker: freezed == previewSticker ? _self.previewSticker : previewSticker // ignore: cast_nullable_to_non_nullable
as StickerPackPreviewSticker?,
  ));
}

/// Create a copy of StickerPackSummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StickerPackPreviewStickerCopyWith<$Res>? get previewSticker {
    if (_self.previewSticker == null) {
    return null;
  }

  return $StickerPackPreviewStickerCopyWith<$Res>(_self.previewSticker!, (value) {
    return _then(_self.copyWith(previewSticker: value));
  });
}
}

/// @nodoc
mixin _$StickerPackDetail {

 String get id; int get ownerUid; String? get ownerName; String get name; String? get description; DateTime? get createdAt; DateTime? get updatedAt; int get stickerCount; bool get isSubscribed; StickerPackPreviewSticker? get previewSticker; List<StickerSummary> get stickers;
/// Create a copy of StickerPackDetail
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StickerPackDetailCopyWith<StickerPackDetail> get copyWith => _$StickerPackDetailCopyWithImpl<StickerPackDetail>(this as StickerPackDetail, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StickerPackDetail&&(identical(other.id, id) || other.id == id)&&(identical(other.ownerUid, ownerUid) || other.ownerUid == ownerUid)&&(identical(other.ownerName, ownerName) || other.ownerName == ownerName)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.stickerCount, stickerCount) || other.stickerCount == stickerCount)&&(identical(other.isSubscribed, isSubscribed) || other.isSubscribed == isSubscribed)&&(identical(other.previewSticker, previewSticker) || other.previewSticker == previewSticker)&&const DeepCollectionEquality().equals(other.stickers, stickers));
}


@override
int get hashCode => Object.hash(runtimeType,id,ownerUid,ownerName,name,description,createdAt,updatedAt,stickerCount,isSubscribed,previewSticker,const DeepCollectionEquality().hash(stickers));

@override
String toString() {
  return 'StickerPackDetail(id: $id, ownerUid: $ownerUid, ownerName: $ownerName, name: $name, description: $description, createdAt: $createdAt, updatedAt: $updatedAt, stickerCount: $stickerCount, isSubscribed: $isSubscribed, previewSticker: $previewSticker, stickers: $stickers)';
}


}

/// @nodoc
abstract mixin class $StickerPackDetailCopyWith<$Res>  {
  factory $StickerPackDetailCopyWith(StickerPackDetail value, $Res Function(StickerPackDetail) _then) = _$StickerPackDetailCopyWithImpl;
@useResult
$Res call({
 String id, int ownerUid, String? ownerName, String name, String? description, DateTime? createdAt, DateTime? updatedAt, int stickerCount, bool isSubscribed, StickerPackPreviewSticker? previewSticker, List<StickerSummary> stickers
});


$StickerPackPreviewStickerCopyWith<$Res>? get previewSticker;

}
/// @nodoc
class _$StickerPackDetailCopyWithImpl<$Res>
    implements $StickerPackDetailCopyWith<$Res> {
  _$StickerPackDetailCopyWithImpl(this._self, this._then);

  final StickerPackDetail _self;
  final $Res Function(StickerPackDetail) _then;

/// Create a copy of StickerPackDetail
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? ownerUid = null,Object? ownerName = freezed,Object? name = null,Object? description = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,Object? stickerCount = null,Object? isSubscribed = null,Object? previewSticker = freezed,Object? stickers = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ownerUid: null == ownerUid ? _self.ownerUid : ownerUid // ignore: cast_nullable_to_non_nullable
as int,ownerName: freezed == ownerName ? _self.ownerName : ownerName // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,stickerCount: null == stickerCount ? _self.stickerCount : stickerCount // ignore: cast_nullable_to_non_nullable
as int,isSubscribed: null == isSubscribed ? _self.isSubscribed : isSubscribed // ignore: cast_nullable_to_non_nullable
as bool,previewSticker: freezed == previewSticker ? _self.previewSticker : previewSticker // ignore: cast_nullable_to_non_nullable
as StickerPackPreviewSticker?,stickers: null == stickers ? _self.stickers : stickers // ignore: cast_nullable_to_non_nullable
as List<StickerSummary>,
  ));
}
/// Create a copy of StickerPackDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StickerPackPreviewStickerCopyWith<$Res>? get previewSticker {
    if (_self.previewSticker == null) {
    return null;
  }

  return $StickerPackPreviewStickerCopyWith<$Res>(_self.previewSticker!, (value) {
    return _then(_self.copyWith(previewSticker: value));
  });
}
}


/// Adds pattern-matching-related methods to [StickerPackDetail].
extension StickerPackDetailPatterns on StickerPackDetail {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StickerPackDetail value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StickerPackDetail() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StickerPackDetail value)  $default,){
final _that = this;
switch (_that) {
case _StickerPackDetail():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StickerPackDetail value)?  $default,){
final _that = this;
switch (_that) {
case _StickerPackDetail() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  int ownerUid,  String? ownerName,  String name,  String? description,  DateTime? createdAt,  DateTime? updatedAt,  int stickerCount,  bool isSubscribed,  StickerPackPreviewSticker? previewSticker,  List<StickerSummary> stickers)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StickerPackDetail() when $default != null:
return $default(_that.id,_that.ownerUid,_that.ownerName,_that.name,_that.description,_that.createdAt,_that.updatedAt,_that.stickerCount,_that.isSubscribed,_that.previewSticker,_that.stickers);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  int ownerUid,  String? ownerName,  String name,  String? description,  DateTime? createdAt,  DateTime? updatedAt,  int stickerCount,  bool isSubscribed,  StickerPackPreviewSticker? previewSticker,  List<StickerSummary> stickers)  $default,) {final _that = this;
switch (_that) {
case _StickerPackDetail():
return $default(_that.id,_that.ownerUid,_that.ownerName,_that.name,_that.description,_that.createdAt,_that.updatedAt,_that.stickerCount,_that.isSubscribed,_that.previewSticker,_that.stickers);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  int ownerUid,  String? ownerName,  String name,  String? description,  DateTime? createdAt,  DateTime? updatedAt,  int stickerCount,  bool isSubscribed,  StickerPackPreviewSticker? previewSticker,  List<StickerSummary> stickers)?  $default,) {final _that = this;
switch (_that) {
case _StickerPackDetail() when $default != null:
return $default(_that.id,_that.ownerUid,_that.ownerName,_that.name,_that.description,_that.createdAt,_that.updatedAt,_that.stickerCount,_that.isSubscribed,_that.previewSticker,_that.stickers);case _:
  return null;

}
}

}

/// @nodoc


class _StickerPackDetail implements StickerPackDetail {
  const _StickerPackDetail({required this.id, required this.ownerUid, this.ownerName, required this.name, this.description, this.createdAt, this.updatedAt, this.stickerCount = 0, this.isSubscribed = false, this.previewSticker, final  List<StickerSummary> stickers = const []}): _stickers = stickers;
  

@override final  String id;
@override final  int ownerUid;
@override final  String? ownerName;
@override final  String name;
@override final  String? description;
@override final  DateTime? createdAt;
@override final  DateTime? updatedAt;
@override@JsonKey() final  int stickerCount;
@override@JsonKey() final  bool isSubscribed;
@override final  StickerPackPreviewSticker? previewSticker;
 final  List<StickerSummary> _stickers;
@override@JsonKey() List<StickerSummary> get stickers {
  if (_stickers is EqualUnmodifiableListView) return _stickers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_stickers);
}


/// Create a copy of StickerPackDetail
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StickerPackDetailCopyWith<_StickerPackDetail> get copyWith => __$StickerPackDetailCopyWithImpl<_StickerPackDetail>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StickerPackDetail&&(identical(other.id, id) || other.id == id)&&(identical(other.ownerUid, ownerUid) || other.ownerUid == ownerUid)&&(identical(other.ownerName, ownerName) || other.ownerName == ownerName)&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.stickerCount, stickerCount) || other.stickerCount == stickerCount)&&(identical(other.isSubscribed, isSubscribed) || other.isSubscribed == isSubscribed)&&(identical(other.previewSticker, previewSticker) || other.previewSticker == previewSticker)&&const DeepCollectionEquality().equals(other._stickers, _stickers));
}


@override
int get hashCode => Object.hash(runtimeType,id,ownerUid,ownerName,name,description,createdAt,updatedAt,stickerCount,isSubscribed,previewSticker,const DeepCollectionEquality().hash(_stickers));

@override
String toString() {
  return 'StickerPackDetail(id: $id, ownerUid: $ownerUid, ownerName: $ownerName, name: $name, description: $description, createdAt: $createdAt, updatedAt: $updatedAt, stickerCount: $stickerCount, isSubscribed: $isSubscribed, previewSticker: $previewSticker, stickers: $stickers)';
}


}

/// @nodoc
abstract mixin class _$StickerPackDetailCopyWith<$Res> implements $StickerPackDetailCopyWith<$Res> {
  factory _$StickerPackDetailCopyWith(_StickerPackDetail value, $Res Function(_StickerPackDetail) _then) = __$StickerPackDetailCopyWithImpl;
@override @useResult
$Res call({
 String id, int ownerUid, String? ownerName, String name, String? description, DateTime? createdAt, DateTime? updatedAt, int stickerCount, bool isSubscribed, StickerPackPreviewSticker? previewSticker, List<StickerSummary> stickers
});


@override $StickerPackPreviewStickerCopyWith<$Res>? get previewSticker;

}
/// @nodoc
class __$StickerPackDetailCopyWithImpl<$Res>
    implements _$StickerPackDetailCopyWith<$Res> {
  __$StickerPackDetailCopyWithImpl(this._self, this._then);

  final _StickerPackDetail _self;
  final $Res Function(_StickerPackDetail) _then;

/// Create a copy of StickerPackDetail
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? ownerUid = null,Object? ownerName = freezed,Object? name = null,Object? description = freezed,Object? createdAt = freezed,Object? updatedAt = freezed,Object? stickerCount = null,Object? isSubscribed = null,Object? previewSticker = freezed,Object? stickers = null,}) {
  return _then(_StickerPackDetail(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ownerUid: null == ownerUid ? _self.ownerUid : ownerUid // ignore: cast_nullable_to_non_nullable
as int,ownerName: freezed == ownerName ? _self.ownerName : ownerName // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,stickerCount: null == stickerCount ? _self.stickerCount : stickerCount // ignore: cast_nullable_to_non_nullable
as int,isSubscribed: null == isSubscribed ? _self.isSubscribed : isSubscribed // ignore: cast_nullable_to_non_nullable
as bool,previewSticker: freezed == previewSticker ? _self.previewSticker : previewSticker // ignore: cast_nullable_to_non_nullable
as StickerPackPreviewSticker?,stickers: null == stickers ? _self._stickers : stickers // ignore: cast_nullable_to_non_nullable
as List<StickerSummary>,
  ));
}

/// Create a copy of StickerPackDetail
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StickerPackPreviewStickerCopyWith<$Res>? get previewSticker {
    if (_self.previewSticker == null) {
    return null;
  }

  return $StickerPackPreviewStickerCopyWith<$Res>(_self.previewSticker!, (value) {
    return _then(_self.copyWith(previewSticker: value));
  });
}
}

// dart format on
