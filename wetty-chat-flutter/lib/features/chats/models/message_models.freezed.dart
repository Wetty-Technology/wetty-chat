// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'message_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Sender {

 int get uid; String? get name; String? get avatarUrl; int get gender;
/// Create a copy of Sender
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SenderCopyWith<Sender> get copyWith => _$SenderCopyWithImpl<Sender>(this as Sender, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Sender&&(identical(other.uid, uid) || other.uid == uid)&&(identical(other.name, name) || other.name == name)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.gender, gender) || other.gender == gender));
}


@override
int get hashCode => Object.hash(runtimeType,uid,name,avatarUrl,gender);

@override
String toString() {
  return 'Sender(uid: $uid, name: $name, avatarUrl: $avatarUrl, gender: $gender)';
}


}

/// @nodoc
abstract mixin class $SenderCopyWith<$Res>  {
  factory $SenderCopyWith(Sender value, $Res Function(Sender) _then) = _$SenderCopyWithImpl;
@useResult
$Res call({
 int uid, String? name, String? avatarUrl, int gender
});




}
/// @nodoc
class _$SenderCopyWithImpl<$Res>
    implements $SenderCopyWith<$Res> {
  _$SenderCopyWithImpl(this._self, this._then);

  final Sender _self;
  final $Res Function(Sender) _then;

/// Create a copy of Sender
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? uid = null,Object? name = freezed,Object? avatarUrl = freezed,Object? gender = null,}) {
  return _then(_self.copyWith(
uid: null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as int,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,gender: null == gender ? _self.gender : gender // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [Sender].
extension SenderPatterns on Sender {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Sender value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Sender() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Sender value)  $default,){
final _that = this;
switch (_that) {
case _Sender():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Sender value)?  $default,){
final _that = this;
switch (_that) {
case _Sender() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int uid,  String? name,  String? avatarUrl,  int gender)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Sender() when $default != null:
return $default(_that.uid,_that.name,_that.avatarUrl,_that.gender);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int uid,  String? name,  String? avatarUrl,  int gender)  $default,) {final _that = this;
switch (_that) {
case _Sender():
return $default(_that.uid,_that.name,_that.avatarUrl,_that.gender);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int uid,  String? name,  String? avatarUrl,  int gender)?  $default,) {final _that = this;
switch (_that) {
case _Sender() when $default != null:
return $default(_that.uid,_that.name,_that.avatarUrl,_that.gender);case _:
  return null;

}
}

}

/// @nodoc


class _Sender implements Sender {
  const _Sender({required this.uid, this.name, this.avatarUrl, this.gender = 0});
  

@override final  int uid;
@override final  String? name;
@override final  String? avatarUrl;
@override@JsonKey() final  int gender;

/// Create a copy of Sender
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SenderCopyWith<_Sender> get copyWith => __$SenderCopyWithImpl<_Sender>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Sender&&(identical(other.uid, uid) || other.uid == uid)&&(identical(other.name, name) || other.name == name)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.gender, gender) || other.gender == gender));
}


@override
int get hashCode => Object.hash(runtimeType,uid,name,avatarUrl,gender);

@override
String toString() {
  return 'Sender(uid: $uid, name: $name, avatarUrl: $avatarUrl, gender: $gender)';
}


}

/// @nodoc
abstract mixin class _$SenderCopyWith<$Res> implements $SenderCopyWith<$Res> {
  factory _$SenderCopyWith(_Sender value, $Res Function(_Sender) _then) = __$SenderCopyWithImpl;
@override @useResult
$Res call({
 int uid, String? name, String? avatarUrl, int gender
});




}
/// @nodoc
class __$SenderCopyWithImpl<$Res>
    implements _$SenderCopyWith<$Res> {
  __$SenderCopyWithImpl(this._self, this._then);

  final _Sender _self;
  final $Res Function(_Sender) _then;

/// Create a copy of Sender
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? uid = null,Object? name = freezed,Object? avatarUrl = freezed,Object? gender = null,}) {
  return _then(_Sender(
uid: null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as int,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,gender: null == gender ? _self.gender : gender // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$AttachmentItem {

 String get id; String get url; String get kind; int get size; String get fileName; int? get width; int? get height; int? get durationMs; List<int>? get waveformSamples;
/// Create a copy of AttachmentItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AttachmentItemCopyWith<AttachmentItem> get copyWith => _$AttachmentItemCopyWithImpl<AttachmentItem>(this as AttachmentItem, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AttachmentItem&&(identical(other.id, id) || other.id == id)&&(identical(other.url, url) || other.url == url)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.size, size) || other.size == size)&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs)&&const DeepCollectionEquality().equals(other.waveformSamples, waveformSamples));
}


@override
int get hashCode => Object.hash(runtimeType,id,url,kind,size,fileName,width,height,durationMs,const DeepCollectionEquality().hash(waveformSamples));

@override
String toString() {
  return 'AttachmentItem(id: $id, url: $url, kind: $kind, size: $size, fileName: $fileName, width: $width, height: $height, durationMs: $durationMs, waveformSamples: $waveformSamples)';
}


}

/// @nodoc
abstract mixin class $AttachmentItemCopyWith<$Res>  {
  factory $AttachmentItemCopyWith(AttachmentItem value, $Res Function(AttachmentItem) _then) = _$AttachmentItemCopyWithImpl;
@useResult
$Res call({
 String id, String url, String kind, int size, String fileName, int? width, int? height, int? durationMs, List<int>? waveformSamples
});




}
/// @nodoc
class _$AttachmentItemCopyWithImpl<$Res>
    implements $AttachmentItemCopyWith<$Res> {
  _$AttachmentItemCopyWithImpl(this._self, this._then);

  final AttachmentItem _self;
  final $Res Function(AttachmentItem) _then;

/// Create a copy of AttachmentItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? url = null,Object? kind = null,Object? size = null,Object? fileName = null,Object? width = freezed,Object? height = freezed,Object? durationMs = freezed,Object? waveformSamples = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,width: freezed == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int?,height: freezed == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int?,durationMs: freezed == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int?,waveformSamples: freezed == waveformSamples ? _self.waveformSamples : waveformSamples // ignore: cast_nullable_to_non_nullable
as List<int>?,
  ));
}

}


/// Adds pattern-matching-related methods to [AttachmentItem].
extension AttachmentItemPatterns on AttachmentItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AttachmentItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AttachmentItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AttachmentItem value)  $default,){
final _that = this;
switch (_that) {
case _AttachmentItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AttachmentItem value)?  $default,){
final _that = this;
switch (_that) {
case _AttachmentItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String url,  String kind,  int size,  String fileName,  int? width,  int? height,  int? durationMs,  List<int>? waveformSamples)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AttachmentItem() when $default != null:
return $default(_that.id,_that.url,_that.kind,_that.size,_that.fileName,_that.width,_that.height,_that.durationMs,_that.waveformSamples);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String url,  String kind,  int size,  String fileName,  int? width,  int? height,  int? durationMs,  List<int>? waveformSamples)  $default,) {final _that = this;
switch (_that) {
case _AttachmentItem():
return $default(_that.id,_that.url,_that.kind,_that.size,_that.fileName,_that.width,_that.height,_that.durationMs,_that.waveformSamples);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String url,  String kind,  int size,  String fileName,  int? width,  int? height,  int? durationMs,  List<int>? waveformSamples)?  $default,) {final _that = this;
switch (_that) {
case _AttachmentItem() when $default != null:
return $default(_that.id,_that.url,_that.kind,_that.size,_that.fileName,_that.width,_that.height,_that.durationMs,_that.waveformSamples);case _:
  return null;

}
}

}

/// @nodoc


class _AttachmentItem extends AttachmentItem {
  const _AttachmentItem({required this.id, required this.url, required this.kind, required this.size, required this.fileName, this.width, this.height, this.durationMs, final  List<int>? waveformSamples}): _waveformSamples = waveformSamples,super._();
  

@override final  String id;
@override final  String url;
@override final  String kind;
@override final  int size;
@override final  String fileName;
@override final  int? width;
@override final  int? height;
@override final  int? durationMs;
 final  List<int>? _waveformSamples;
@override List<int>? get waveformSamples {
  final value = _waveformSamples;
  if (value == null) return null;
  if (_waveformSamples is EqualUnmodifiableListView) return _waveformSamples;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


/// Create a copy of AttachmentItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AttachmentItemCopyWith<_AttachmentItem> get copyWith => __$AttachmentItemCopyWithImpl<_AttachmentItem>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AttachmentItem&&(identical(other.id, id) || other.id == id)&&(identical(other.url, url) || other.url == url)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.size, size) || other.size == size)&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.durationMs, durationMs) || other.durationMs == durationMs)&&const DeepCollectionEquality().equals(other._waveformSamples, _waveformSamples));
}


@override
int get hashCode => Object.hash(runtimeType,id,url,kind,size,fileName,width,height,durationMs,const DeepCollectionEquality().hash(_waveformSamples));

@override
String toString() {
  return 'AttachmentItem(id: $id, url: $url, kind: $kind, size: $size, fileName: $fileName, width: $width, height: $height, durationMs: $durationMs, waveformSamples: $waveformSamples)';
}


}

/// @nodoc
abstract mixin class _$AttachmentItemCopyWith<$Res> implements $AttachmentItemCopyWith<$Res> {
  factory _$AttachmentItemCopyWith(_AttachmentItem value, $Res Function(_AttachmentItem) _then) = __$AttachmentItemCopyWithImpl;
@override @useResult
$Res call({
 String id, String url, String kind, int size, String fileName, int? width, int? height, int? durationMs, List<int>? waveformSamples
});




}
/// @nodoc
class __$AttachmentItemCopyWithImpl<$Res>
    implements _$AttachmentItemCopyWith<$Res> {
  __$AttachmentItemCopyWithImpl(this._self, this._then);

  final _AttachmentItem _self;
  final $Res Function(_AttachmentItem) _then;

/// Create a copy of AttachmentItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? url = null,Object? kind = null,Object? size = null,Object? fileName = null,Object? width = freezed,Object? height = freezed,Object? durationMs = freezed,Object? waveformSamples = freezed,}) {
  return _then(_AttachmentItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,url: null == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as int,fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,width: freezed == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int?,height: freezed == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int?,durationMs: freezed == durationMs ? _self.durationMs : durationMs // ignore: cast_nullable_to_non_nullable
as int?,waveformSamples: freezed == waveformSamples ? _self._waveformSamples : waveformSamples // ignore: cast_nullable_to_non_nullable
as List<int>?,
  ));
}


}

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

/// @nodoc
mixin _$ReactionReactor {

 int get uid; String? get name; String? get avatarUrl;
/// Create a copy of ReactionReactor
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReactionReactorCopyWith<ReactionReactor> get copyWith => _$ReactionReactorCopyWithImpl<ReactionReactor>(this as ReactionReactor, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReactionReactor&&(identical(other.uid, uid) || other.uid == uid)&&(identical(other.name, name) || other.name == name)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl));
}


@override
int get hashCode => Object.hash(runtimeType,uid,name,avatarUrl);

@override
String toString() {
  return 'ReactionReactor(uid: $uid, name: $name, avatarUrl: $avatarUrl)';
}


}

/// @nodoc
abstract mixin class $ReactionReactorCopyWith<$Res>  {
  factory $ReactionReactorCopyWith(ReactionReactor value, $Res Function(ReactionReactor) _then) = _$ReactionReactorCopyWithImpl;
@useResult
$Res call({
 int uid, String? name, String? avatarUrl
});




}
/// @nodoc
class _$ReactionReactorCopyWithImpl<$Res>
    implements $ReactionReactorCopyWith<$Res> {
  _$ReactionReactorCopyWithImpl(this._self, this._then);

  final ReactionReactor _self;
  final $Res Function(ReactionReactor) _then;

/// Create a copy of ReactionReactor
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? uid = null,Object? name = freezed,Object? avatarUrl = freezed,}) {
  return _then(_self.copyWith(
uid: null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as int,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ReactionReactor].
extension ReactionReactorPatterns on ReactionReactor {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReactionReactor value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReactionReactor() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReactionReactor value)  $default,){
final _that = this;
switch (_that) {
case _ReactionReactor():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReactionReactor value)?  $default,){
final _that = this;
switch (_that) {
case _ReactionReactor() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int uid,  String? name,  String? avatarUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReactionReactor() when $default != null:
return $default(_that.uid,_that.name,_that.avatarUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int uid,  String? name,  String? avatarUrl)  $default,) {final _that = this;
switch (_that) {
case _ReactionReactor():
return $default(_that.uid,_that.name,_that.avatarUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int uid,  String? name,  String? avatarUrl)?  $default,) {final _that = this;
switch (_that) {
case _ReactionReactor() when $default != null:
return $default(_that.uid,_that.name,_that.avatarUrl);case _:
  return null;

}
}

}

/// @nodoc


class _ReactionReactor implements ReactionReactor {
  const _ReactionReactor({required this.uid, this.name, this.avatarUrl});
  

@override final  int uid;
@override final  String? name;
@override final  String? avatarUrl;

/// Create a copy of ReactionReactor
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReactionReactorCopyWith<_ReactionReactor> get copyWith => __$ReactionReactorCopyWithImpl<_ReactionReactor>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReactionReactor&&(identical(other.uid, uid) || other.uid == uid)&&(identical(other.name, name) || other.name == name)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl));
}


@override
int get hashCode => Object.hash(runtimeType,uid,name,avatarUrl);

@override
String toString() {
  return 'ReactionReactor(uid: $uid, name: $name, avatarUrl: $avatarUrl)';
}


}

/// @nodoc
abstract mixin class _$ReactionReactorCopyWith<$Res> implements $ReactionReactorCopyWith<$Res> {
  factory _$ReactionReactorCopyWith(_ReactionReactor value, $Res Function(_ReactionReactor) _then) = __$ReactionReactorCopyWithImpl;
@override @useResult
$Res call({
 int uid, String? name, String? avatarUrl
});




}
/// @nodoc
class __$ReactionReactorCopyWithImpl<$Res>
    implements _$ReactionReactorCopyWith<$Res> {
  __$ReactionReactorCopyWithImpl(this._self, this._then);

  final _ReactionReactor _self;
  final $Res Function(_ReactionReactor) _then;

/// Create a copy of ReactionReactor
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? uid = null,Object? name = freezed,Object? avatarUrl = freezed,}) {
  return _then(_ReactionReactor(
uid: null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as int,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$ReactionSummary {

 String get emoji; int get count; bool? get reactedByMe; List<ReactionReactor>? get reactors;
/// Create a copy of ReactionSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReactionSummaryCopyWith<ReactionSummary> get copyWith => _$ReactionSummaryCopyWithImpl<ReactionSummary>(this as ReactionSummary, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReactionSummary&&(identical(other.emoji, emoji) || other.emoji == emoji)&&(identical(other.count, count) || other.count == count)&&(identical(other.reactedByMe, reactedByMe) || other.reactedByMe == reactedByMe)&&const DeepCollectionEquality().equals(other.reactors, reactors));
}


@override
int get hashCode => Object.hash(runtimeType,emoji,count,reactedByMe,const DeepCollectionEquality().hash(reactors));

@override
String toString() {
  return 'ReactionSummary(emoji: $emoji, count: $count, reactedByMe: $reactedByMe, reactors: $reactors)';
}


}

/// @nodoc
abstract mixin class $ReactionSummaryCopyWith<$Res>  {
  factory $ReactionSummaryCopyWith(ReactionSummary value, $Res Function(ReactionSummary) _then) = _$ReactionSummaryCopyWithImpl;
@useResult
$Res call({
 String emoji, int count, bool? reactedByMe, List<ReactionReactor>? reactors
});




}
/// @nodoc
class _$ReactionSummaryCopyWithImpl<$Res>
    implements $ReactionSummaryCopyWith<$Res> {
  _$ReactionSummaryCopyWithImpl(this._self, this._then);

  final ReactionSummary _self;
  final $Res Function(ReactionSummary) _then;

/// Create a copy of ReactionSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? emoji = null,Object? count = null,Object? reactedByMe = freezed,Object? reactors = freezed,}) {
  return _then(_self.copyWith(
emoji: null == emoji ? _self.emoji : emoji // ignore: cast_nullable_to_non_nullable
as String,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,reactedByMe: freezed == reactedByMe ? _self.reactedByMe : reactedByMe // ignore: cast_nullable_to_non_nullable
as bool?,reactors: freezed == reactors ? _self.reactors : reactors // ignore: cast_nullable_to_non_nullable
as List<ReactionReactor>?,
  ));
}

}


/// Adds pattern-matching-related methods to [ReactionSummary].
extension ReactionSummaryPatterns on ReactionSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReactionSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReactionSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReactionSummary value)  $default,){
final _that = this;
switch (_that) {
case _ReactionSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReactionSummary value)?  $default,){
final _that = this;
switch (_that) {
case _ReactionSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String emoji,  int count,  bool? reactedByMe,  List<ReactionReactor>? reactors)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReactionSummary() when $default != null:
return $default(_that.emoji,_that.count,_that.reactedByMe,_that.reactors);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String emoji,  int count,  bool? reactedByMe,  List<ReactionReactor>? reactors)  $default,) {final _that = this;
switch (_that) {
case _ReactionSummary():
return $default(_that.emoji,_that.count,_that.reactedByMe,_that.reactors);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String emoji,  int count,  bool? reactedByMe,  List<ReactionReactor>? reactors)?  $default,) {final _that = this;
switch (_that) {
case _ReactionSummary() when $default != null:
return $default(_that.emoji,_that.count,_that.reactedByMe,_that.reactors);case _:
  return null;

}
}

}

/// @nodoc


class _ReactionSummary implements ReactionSummary {
  const _ReactionSummary({required this.emoji, required this.count, this.reactedByMe, final  List<ReactionReactor>? reactors}): _reactors = reactors;
  

@override final  String emoji;
@override final  int count;
@override final  bool? reactedByMe;
 final  List<ReactionReactor>? _reactors;
@override List<ReactionReactor>? get reactors {
  final value = _reactors;
  if (value == null) return null;
  if (_reactors is EqualUnmodifiableListView) return _reactors;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}


/// Create a copy of ReactionSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReactionSummaryCopyWith<_ReactionSummary> get copyWith => __$ReactionSummaryCopyWithImpl<_ReactionSummary>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReactionSummary&&(identical(other.emoji, emoji) || other.emoji == emoji)&&(identical(other.count, count) || other.count == count)&&(identical(other.reactedByMe, reactedByMe) || other.reactedByMe == reactedByMe)&&const DeepCollectionEquality().equals(other._reactors, _reactors));
}


@override
int get hashCode => Object.hash(runtimeType,emoji,count,reactedByMe,const DeepCollectionEquality().hash(_reactors));

@override
String toString() {
  return 'ReactionSummary(emoji: $emoji, count: $count, reactedByMe: $reactedByMe, reactors: $reactors)';
}


}

/// @nodoc
abstract mixin class _$ReactionSummaryCopyWith<$Res> implements $ReactionSummaryCopyWith<$Res> {
  factory _$ReactionSummaryCopyWith(_ReactionSummary value, $Res Function(_ReactionSummary) _then) = __$ReactionSummaryCopyWithImpl;
@override @useResult
$Res call({
 String emoji, int count, bool? reactedByMe, List<ReactionReactor>? reactors
});




}
/// @nodoc
class __$ReactionSummaryCopyWithImpl<$Res>
    implements _$ReactionSummaryCopyWith<$Res> {
  __$ReactionSummaryCopyWithImpl(this._self, this._then);

  final _ReactionSummary _self;
  final $Res Function(_ReactionSummary) _then;

/// Create a copy of ReactionSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? emoji = null,Object? count = null,Object? reactedByMe = freezed,Object? reactors = freezed,}) {
  return _then(_ReactionSummary(
emoji: null == emoji ? _self.emoji : emoji // ignore: cast_nullable_to_non_nullable
as String,count: null == count ? _self.count : count // ignore: cast_nullable_to_non_nullable
as int,reactedByMe: freezed == reactedByMe ? _self.reactedByMe : reactedByMe // ignore: cast_nullable_to_non_nullable
as bool?,reactors: freezed == reactors ? _self._reactors : reactors // ignore: cast_nullable_to_non_nullable
as List<ReactionReactor>?,
  ));
}


}

/// @nodoc
mixin _$UserGroupInfo {

 int get groupId; String? get name; String? get chatGroupColor; String? get chatGroupColorDark;
/// Create a copy of UserGroupInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserGroupInfoCopyWith<UserGroupInfo> get copyWith => _$UserGroupInfoCopyWithImpl<UserGroupInfo>(this as UserGroupInfo, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserGroupInfo&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.name, name) || other.name == name)&&(identical(other.chatGroupColor, chatGroupColor) || other.chatGroupColor == chatGroupColor)&&(identical(other.chatGroupColorDark, chatGroupColorDark) || other.chatGroupColorDark == chatGroupColorDark));
}


@override
int get hashCode => Object.hash(runtimeType,groupId,name,chatGroupColor,chatGroupColorDark);

@override
String toString() {
  return 'UserGroupInfo(groupId: $groupId, name: $name, chatGroupColor: $chatGroupColor, chatGroupColorDark: $chatGroupColorDark)';
}


}

/// @nodoc
abstract mixin class $UserGroupInfoCopyWith<$Res>  {
  factory $UserGroupInfoCopyWith(UserGroupInfo value, $Res Function(UserGroupInfo) _then) = _$UserGroupInfoCopyWithImpl;
@useResult
$Res call({
 int groupId, String? name, String? chatGroupColor, String? chatGroupColorDark
});




}
/// @nodoc
class _$UserGroupInfoCopyWithImpl<$Res>
    implements $UserGroupInfoCopyWith<$Res> {
  _$UserGroupInfoCopyWithImpl(this._self, this._then);

  final UserGroupInfo _self;
  final $Res Function(UserGroupInfo) _then;

/// Create a copy of UserGroupInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? groupId = null,Object? name = freezed,Object? chatGroupColor = freezed,Object? chatGroupColorDark = freezed,}) {
  return _then(_self.copyWith(
groupId: null == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as int,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,chatGroupColor: freezed == chatGroupColor ? _self.chatGroupColor : chatGroupColor // ignore: cast_nullable_to_non_nullable
as String?,chatGroupColorDark: freezed == chatGroupColorDark ? _self.chatGroupColorDark : chatGroupColorDark // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [UserGroupInfo].
extension UserGroupInfoPatterns on UserGroupInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserGroupInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserGroupInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserGroupInfo value)  $default,){
final _that = this;
switch (_that) {
case _UserGroupInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserGroupInfo value)?  $default,){
final _that = this;
switch (_that) {
case _UserGroupInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int groupId,  String? name,  String? chatGroupColor,  String? chatGroupColorDark)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserGroupInfo() when $default != null:
return $default(_that.groupId,_that.name,_that.chatGroupColor,_that.chatGroupColorDark);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int groupId,  String? name,  String? chatGroupColor,  String? chatGroupColorDark)  $default,) {final _that = this;
switch (_that) {
case _UserGroupInfo():
return $default(_that.groupId,_that.name,_that.chatGroupColor,_that.chatGroupColorDark);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int groupId,  String? name,  String? chatGroupColor,  String? chatGroupColorDark)?  $default,) {final _that = this;
switch (_that) {
case _UserGroupInfo() when $default != null:
return $default(_that.groupId,_that.name,_that.chatGroupColor,_that.chatGroupColorDark);case _:
  return null;

}
}

}

/// @nodoc


class _UserGroupInfo implements UserGroupInfo {
  const _UserGroupInfo({required this.groupId, this.name, this.chatGroupColor, this.chatGroupColorDark});
  

@override final  int groupId;
@override final  String? name;
@override final  String? chatGroupColor;
@override final  String? chatGroupColorDark;

/// Create a copy of UserGroupInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserGroupInfoCopyWith<_UserGroupInfo> get copyWith => __$UserGroupInfoCopyWithImpl<_UserGroupInfo>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserGroupInfo&&(identical(other.groupId, groupId) || other.groupId == groupId)&&(identical(other.name, name) || other.name == name)&&(identical(other.chatGroupColor, chatGroupColor) || other.chatGroupColor == chatGroupColor)&&(identical(other.chatGroupColorDark, chatGroupColorDark) || other.chatGroupColorDark == chatGroupColorDark));
}


@override
int get hashCode => Object.hash(runtimeType,groupId,name,chatGroupColor,chatGroupColorDark);

@override
String toString() {
  return 'UserGroupInfo(groupId: $groupId, name: $name, chatGroupColor: $chatGroupColor, chatGroupColorDark: $chatGroupColorDark)';
}


}

/// @nodoc
abstract mixin class _$UserGroupInfoCopyWith<$Res> implements $UserGroupInfoCopyWith<$Res> {
  factory _$UserGroupInfoCopyWith(_UserGroupInfo value, $Res Function(_UserGroupInfo) _then) = __$UserGroupInfoCopyWithImpl;
@override @useResult
$Res call({
 int groupId, String? name, String? chatGroupColor, String? chatGroupColorDark
});




}
/// @nodoc
class __$UserGroupInfoCopyWithImpl<$Res>
    implements _$UserGroupInfoCopyWith<$Res> {
  __$UserGroupInfoCopyWithImpl(this._self, this._then);

  final _UserGroupInfo _self;
  final $Res Function(_UserGroupInfo) _then;

/// Create a copy of UserGroupInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? groupId = null,Object? name = freezed,Object? chatGroupColor = freezed,Object? chatGroupColorDark = freezed,}) {
  return _then(_UserGroupInfo(
groupId: null == groupId ? _self.groupId : groupId // ignore: cast_nullable_to_non_nullable
as int,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,chatGroupColor: freezed == chatGroupColor ? _self.chatGroupColor : chatGroupColor // ignore: cast_nullable_to_non_nullable
as String?,chatGroupColorDark: freezed == chatGroupColorDark ? _self.chatGroupColorDark : chatGroupColorDark // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$MentionInfo {

 int get uid; String? get username; String? get avatarUrl; int get gender; UserGroupInfo? get userGroup;
/// Create a copy of MentionInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MentionInfoCopyWith<MentionInfo> get copyWith => _$MentionInfoCopyWithImpl<MentionInfo>(this as MentionInfo, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MentionInfo&&(identical(other.uid, uid) || other.uid == uid)&&(identical(other.username, username) || other.username == username)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.gender, gender) || other.gender == gender)&&(identical(other.userGroup, userGroup) || other.userGroup == userGroup));
}


@override
int get hashCode => Object.hash(runtimeType,uid,username,avatarUrl,gender,userGroup);

@override
String toString() {
  return 'MentionInfo(uid: $uid, username: $username, avatarUrl: $avatarUrl, gender: $gender, userGroup: $userGroup)';
}


}

/// @nodoc
abstract mixin class $MentionInfoCopyWith<$Res>  {
  factory $MentionInfoCopyWith(MentionInfo value, $Res Function(MentionInfo) _then) = _$MentionInfoCopyWithImpl;
@useResult
$Res call({
 int uid, String? username, String? avatarUrl, int gender, UserGroupInfo? userGroup
});


$UserGroupInfoCopyWith<$Res>? get userGroup;

}
/// @nodoc
class _$MentionInfoCopyWithImpl<$Res>
    implements $MentionInfoCopyWith<$Res> {
  _$MentionInfoCopyWithImpl(this._self, this._then);

  final MentionInfo _self;
  final $Res Function(MentionInfo) _then;

/// Create a copy of MentionInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? uid = null,Object? username = freezed,Object? avatarUrl = freezed,Object? gender = null,Object? userGroup = freezed,}) {
  return _then(_self.copyWith(
uid: null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as int,username: freezed == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,gender: null == gender ? _self.gender : gender // ignore: cast_nullable_to_non_nullable
as int,userGroup: freezed == userGroup ? _self.userGroup : userGroup // ignore: cast_nullable_to_non_nullable
as UserGroupInfo?,
  ));
}
/// Create a copy of MentionInfo
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserGroupInfoCopyWith<$Res>? get userGroup {
    if (_self.userGroup == null) {
    return null;
  }

  return $UserGroupInfoCopyWith<$Res>(_self.userGroup!, (value) {
    return _then(_self.copyWith(userGroup: value));
  });
}
}


/// Adds pattern-matching-related methods to [MentionInfo].
extension MentionInfoPatterns on MentionInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MentionInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MentionInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MentionInfo value)  $default,){
final _that = this;
switch (_that) {
case _MentionInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MentionInfo value)?  $default,){
final _that = this;
switch (_that) {
case _MentionInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int uid,  String? username,  String? avatarUrl,  int gender,  UserGroupInfo? userGroup)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MentionInfo() when $default != null:
return $default(_that.uid,_that.username,_that.avatarUrl,_that.gender,_that.userGroup);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int uid,  String? username,  String? avatarUrl,  int gender,  UserGroupInfo? userGroup)  $default,) {final _that = this;
switch (_that) {
case _MentionInfo():
return $default(_that.uid,_that.username,_that.avatarUrl,_that.gender,_that.userGroup);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int uid,  String? username,  String? avatarUrl,  int gender,  UserGroupInfo? userGroup)?  $default,) {final _that = this;
switch (_that) {
case _MentionInfo() when $default != null:
return $default(_that.uid,_that.username,_that.avatarUrl,_that.gender,_that.userGroup);case _:
  return null;

}
}

}

/// @nodoc


class _MentionInfo implements MentionInfo {
  const _MentionInfo({required this.uid, this.username, this.avatarUrl, this.gender = 0, this.userGroup});
  

@override final  int uid;
@override final  String? username;
@override final  String? avatarUrl;
@override@JsonKey() final  int gender;
@override final  UserGroupInfo? userGroup;

/// Create a copy of MentionInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MentionInfoCopyWith<_MentionInfo> get copyWith => __$MentionInfoCopyWithImpl<_MentionInfo>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MentionInfo&&(identical(other.uid, uid) || other.uid == uid)&&(identical(other.username, username) || other.username == username)&&(identical(other.avatarUrl, avatarUrl) || other.avatarUrl == avatarUrl)&&(identical(other.gender, gender) || other.gender == gender)&&(identical(other.userGroup, userGroup) || other.userGroup == userGroup));
}


@override
int get hashCode => Object.hash(runtimeType,uid,username,avatarUrl,gender,userGroup);

@override
String toString() {
  return 'MentionInfo(uid: $uid, username: $username, avatarUrl: $avatarUrl, gender: $gender, userGroup: $userGroup)';
}


}

/// @nodoc
abstract mixin class _$MentionInfoCopyWith<$Res> implements $MentionInfoCopyWith<$Res> {
  factory _$MentionInfoCopyWith(_MentionInfo value, $Res Function(_MentionInfo) _then) = __$MentionInfoCopyWithImpl;
@override @useResult
$Res call({
 int uid, String? username, String? avatarUrl, int gender, UserGroupInfo? userGroup
});


@override $UserGroupInfoCopyWith<$Res>? get userGroup;

}
/// @nodoc
class __$MentionInfoCopyWithImpl<$Res>
    implements _$MentionInfoCopyWith<$Res> {
  __$MentionInfoCopyWithImpl(this._self, this._then);

  final _MentionInfo _self;
  final $Res Function(_MentionInfo) _then;

/// Create a copy of MentionInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? uid = null,Object? username = freezed,Object? avatarUrl = freezed,Object? gender = null,Object? userGroup = freezed,}) {
  return _then(_MentionInfo(
uid: null == uid ? _self.uid : uid // ignore: cast_nullable_to_non_nullable
as int,username: freezed == username ? _self.username : username // ignore: cast_nullable_to_non_nullable
as String?,avatarUrl: freezed == avatarUrl ? _self.avatarUrl : avatarUrl // ignore: cast_nullable_to_non_nullable
as String?,gender: null == gender ? _self.gender : gender // ignore: cast_nullable_to_non_nullable
as int,userGroup: freezed == userGroup ? _self.userGroup : userGroup // ignore: cast_nullable_to_non_nullable
as UserGroupInfo?,
  ));
}

/// Create a copy of MentionInfo
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserGroupInfoCopyWith<$Res>? get userGroup {
    if (_self.userGroup == null) {
    return null;
  }

  return $UserGroupInfoCopyWith<$Res>(_self.userGroup!, (value) {
    return _then(_self.copyWith(userGroup: value));
  });
}
}

/// @nodoc
mixin _$ReplyToMessage {

 int get id; String? get message; String get messageType; StickerSummary? get sticker; Sender get sender; bool get isDeleted; List<AttachmentItem> get attachments; List<ReactionSummary> get reactions; String? get firstAttachmentKind; List<MentionInfo> get mentions;
/// Create a copy of ReplyToMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReplyToMessageCopyWith<ReplyToMessage> get copyWith => _$ReplyToMessageCopyWithImpl<ReplyToMessage>(this as ReplyToMessage, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReplyToMessage&&(identical(other.id, id) || other.id == id)&&(identical(other.message, message) || other.message == message)&&(identical(other.messageType, messageType) || other.messageType == messageType)&&(identical(other.sticker, sticker) || other.sticker == sticker)&&(identical(other.sender, sender) || other.sender == sender)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&const DeepCollectionEquality().equals(other.attachments, attachments)&&const DeepCollectionEquality().equals(other.reactions, reactions)&&(identical(other.firstAttachmentKind, firstAttachmentKind) || other.firstAttachmentKind == firstAttachmentKind)&&const DeepCollectionEquality().equals(other.mentions, mentions));
}


@override
int get hashCode => Object.hash(runtimeType,id,message,messageType,sticker,sender,isDeleted,const DeepCollectionEquality().hash(attachments),const DeepCollectionEquality().hash(reactions),firstAttachmentKind,const DeepCollectionEquality().hash(mentions));

@override
String toString() {
  return 'ReplyToMessage(id: $id, message: $message, messageType: $messageType, sticker: $sticker, sender: $sender, isDeleted: $isDeleted, attachments: $attachments, reactions: $reactions, firstAttachmentKind: $firstAttachmentKind, mentions: $mentions)';
}


}

/// @nodoc
abstract mixin class $ReplyToMessageCopyWith<$Res>  {
  factory $ReplyToMessageCopyWith(ReplyToMessage value, $Res Function(ReplyToMessage) _then) = _$ReplyToMessageCopyWithImpl;
@useResult
$Res call({
 int id, String? message, String messageType, StickerSummary? sticker, Sender sender, bool isDeleted, List<AttachmentItem> attachments, List<ReactionSummary> reactions, String? firstAttachmentKind, List<MentionInfo> mentions
});


$StickerSummaryCopyWith<$Res>? get sticker;$SenderCopyWith<$Res> get sender;

}
/// @nodoc
class _$ReplyToMessageCopyWithImpl<$Res>
    implements $ReplyToMessageCopyWith<$Res> {
  _$ReplyToMessageCopyWithImpl(this._self, this._then);

  final ReplyToMessage _self;
  final $Res Function(ReplyToMessage) _then;

/// Create a copy of ReplyToMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? message = freezed,Object? messageType = null,Object? sticker = freezed,Object? sender = null,Object? isDeleted = null,Object? attachments = null,Object? reactions = null,Object? firstAttachmentKind = freezed,Object? mentions = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,messageType: null == messageType ? _self.messageType : messageType // ignore: cast_nullable_to_non_nullable
as String,sticker: freezed == sticker ? _self.sticker : sticker // ignore: cast_nullable_to_non_nullable
as StickerSummary?,sender: null == sender ? _self.sender : sender // ignore: cast_nullable_to_non_nullable
as Sender,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,attachments: null == attachments ? _self.attachments : attachments // ignore: cast_nullable_to_non_nullable
as List<AttachmentItem>,reactions: null == reactions ? _self.reactions : reactions // ignore: cast_nullable_to_non_nullable
as List<ReactionSummary>,firstAttachmentKind: freezed == firstAttachmentKind ? _self.firstAttachmentKind : firstAttachmentKind // ignore: cast_nullable_to_non_nullable
as String?,mentions: null == mentions ? _self.mentions : mentions // ignore: cast_nullable_to_non_nullable
as List<MentionInfo>,
  ));
}
/// Create a copy of ReplyToMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StickerSummaryCopyWith<$Res>? get sticker {
    if (_self.sticker == null) {
    return null;
  }

  return $StickerSummaryCopyWith<$Res>(_self.sticker!, (value) {
    return _then(_self.copyWith(sticker: value));
  });
}/// Create a copy of ReplyToMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SenderCopyWith<$Res> get sender {
  
  return $SenderCopyWith<$Res>(_self.sender, (value) {
    return _then(_self.copyWith(sender: value));
  });
}
}


/// Adds pattern-matching-related methods to [ReplyToMessage].
extension ReplyToMessagePatterns on ReplyToMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReplyToMessage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReplyToMessage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReplyToMessage value)  $default,){
final _that = this;
switch (_that) {
case _ReplyToMessage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReplyToMessage value)?  $default,){
final _that = this;
switch (_that) {
case _ReplyToMessage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String? message,  String messageType,  StickerSummary? sticker,  Sender sender,  bool isDeleted,  List<AttachmentItem> attachments,  List<ReactionSummary> reactions,  String? firstAttachmentKind,  List<MentionInfo> mentions)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReplyToMessage() when $default != null:
return $default(_that.id,_that.message,_that.messageType,_that.sticker,_that.sender,_that.isDeleted,_that.attachments,_that.reactions,_that.firstAttachmentKind,_that.mentions);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String? message,  String messageType,  StickerSummary? sticker,  Sender sender,  bool isDeleted,  List<AttachmentItem> attachments,  List<ReactionSummary> reactions,  String? firstAttachmentKind,  List<MentionInfo> mentions)  $default,) {final _that = this;
switch (_that) {
case _ReplyToMessage():
return $default(_that.id,_that.message,_that.messageType,_that.sticker,_that.sender,_that.isDeleted,_that.attachments,_that.reactions,_that.firstAttachmentKind,_that.mentions);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String? message,  String messageType,  StickerSummary? sticker,  Sender sender,  bool isDeleted,  List<AttachmentItem> attachments,  List<ReactionSummary> reactions,  String? firstAttachmentKind,  List<MentionInfo> mentions)?  $default,) {final _that = this;
switch (_that) {
case _ReplyToMessage() when $default != null:
return $default(_that.id,_that.message,_that.messageType,_that.sticker,_that.sender,_that.isDeleted,_that.attachments,_that.reactions,_that.firstAttachmentKind,_that.mentions);case _:
  return null;

}
}

}

/// @nodoc


class _ReplyToMessage implements ReplyToMessage {
  const _ReplyToMessage({required this.id, this.message, this.messageType = 'text', this.sticker, required this.sender, this.isDeleted = false, final  List<AttachmentItem> attachments = const [], final  List<ReactionSummary> reactions = const [], this.firstAttachmentKind, final  List<MentionInfo> mentions = const []}): _attachments = attachments,_reactions = reactions,_mentions = mentions;
  

@override final  int id;
@override final  String? message;
@override@JsonKey() final  String messageType;
@override final  StickerSummary? sticker;
@override final  Sender sender;
@override@JsonKey() final  bool isDeleted;
 final  List<AttachmentItem> _attachments;
@override@JsonKey() List<AttachmentItem> get attachments {
  if (_attachments is EqualUnmodifiableListView) return _attachments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_attachments);
}

 final  List<ReactionSummary> _reactions;
@override@JsonKey() List<ReactionSummary> get reactions {
  if (_reactions is EqualUnmodifiableListView) return _reactions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_reactions);
}

@override final  String? firstAttachmentKind;
 final  List<MentionInfo> _mentions;
@override@JsonKey() List<MentionInfo> get mentions {
  if (_mentions is EqualUnmodifiableListView) return _mentions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_mentions);
}


/// Create a copy of ReplyToMessage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReplyToMessageCopyWith<_ReplyToMessage> get copyWith => __$ReplyToMessageCopyWithImpl<_ReplyToMessage>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReplyToMessage&&(identical(other.id, id) || other.id == id)&&(identical(other.message, message) || other.message == message)&&(identical(other.messageType, messageType) || other.messageType == messageType)&&(identical(other.sticker, sticker) || other.sticker == sticker)&&(identical(other.sender, sender) || other.sender == sender)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&const DeepCollectionEquality().equals(other._attachments, _attachments)&&const DeepCollectionEquality().equals(other._reactions, _reactions)&&(identical(other.firstAttachmentKind, firstAttachmentKind) || other.firstAttachmentKind == firstAttachmentKind)&&const DeepCollectionEquality().equals(other._mentions, _mentions));
}


@override
int get hashCode => Object.hash(runtimeType,id,message,messageType,sticker,sender,isDeleted,const DeepCollectionEquality().hash(_attachments),const DeepCollectionEquality().hash(_reactions),firstAttachmentKind,const DeepCollectionEquality().hash(_mentions));

@override
String toString() {
  return 'ReplyToMessage(id: $id, message: $message, messageType: $messageType, sticker: $sticker, sender: $sender, isDeleted: $isDeleted, attachments: $attachments, reactions: $reactions, firstAttachmentKind: $firstAttachmentKind, mentions: $mentions)';
}


}

/// @nodoc
abstract mixin class _$ReplyToMessageCopyWith<$Res> implements $ReplyToMessageCopyWith<$Res> {
  factory _$ReplyToMessageCopyWith(_ReplyToMessage value, $Res Function(_ReplyToMessage) _then) = __$ReplyToMessageCopyWithImpl;
@override @useResult
$Res call({
 int id, String? message, String messageType, StickerSummary? sticker, Sender sender, bool isDeleted, List<AttachmentItem> attachments, List<ReactionSummary> reactions, String? firstAttachmentKind, List<MentionInfo> mentions
});


@override $StickerSummaryCopyWith<$Res>? get sticker;@override $SenderCopyWith<$Res> get sender;

}
/// @nodoc
class __$ReplyToMessageCopyWithImpl<$Res>
    implements _$ReplyToMessageCopyWith<$Res> {
  __$ReplyToMessageCopyWithImpl(this._self, this._then);

  final _ReplyToMessage _self;
  final $Res Function(_ReplyToMessage) _then;

/// Create a copy of ReplyToMessage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? message = freezed,Object? messageType = null,Object? sticker = freezed,Object? sender = null,Object? isDeleted = null,Object? attachments = null,Object? reactions = null,Object? firstAttachmentKind = freezed,Object? mentions = null,}) {
  return _then(_ReplyToMessage(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,messageType: null == messageType ? _self.messageType : messageType // ignore: cast_nullable_to_non_nullable
as String,sticker: freezed == sticker ? _self.sticker : sticker // ignore: cast_nullable_to_non_nullable
as StickerSummary?,sender: null == sender ? _self.sender : sender // ignore: cast_nullable_to_non_nullable
as Sender,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,attachments: null == attachments ? _self._attachments : attachments // ignore: cast_nullable_to_non_nullable
as List<AttachmentItem>,reactions: null == reactions ? _self._reactions : reactions // ignore: cast_nullable_to_non_nullable
as List<ReactionSummary>,firstAttachmentKind: freezed == firstAttachmentKind ? _self.firstAttachmentKind : firstAttachmentKind // ignore: cast_nullable_to_non_nullable
as String?,mentions: null == mentions ? _self._mentions : mentions // ignore: cast_nullable_to_non_nullable
as List<MentionInfo>,
  ));
}

/// Create a copy of ReplyToMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StickerSummaryCopyWith<$Res>? get sticker {
    if (_self.sticker == null) {
    return null;
  }

  return $StickerSummaryCopyWith<$Res>(_self.sticker!, (value) {
    return _then(_self.copyWith(sticker: value));
  });
}/// Create a copy of ReplyToMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SenderCopyWith<$Res> get sender {
  
  return $SenderCopyWith<$Res>(_self.sender, (value) {
    return _then(_self.copyWith(sender: value));
  });
}
}

/// @nodoc
mixin _$ThreadInfo {

 int get replyCount;
/// Create a copy of ThreadInfo
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ThreadInfoCopyWith<ThreadInfo> get copyWith => _$ThreadInfoCopyWithImpl<ThreadInfo>(this as ThreadInfo, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ThreadInfo&&(identical(other.replyCount, replyCount) || other.replyCount == replyCount));
}


@override
int get hashCode => Object.hash(runtimeType,replyCount);

@override
String toString() {
  return 'ThreadInfo(replyCount: $replyCount)';
}


}

/// @nodoc
abstract mixin class $ThreadInfoCopyWith<$Res>  {
  factory $ThreadInfoCopyWith(ThreadInfo value, $Res Function(ThreadInfo) _then) = _$ThreadInfoCopyWithImpl;
@useResult
$Res call({
 int replyCount
});




}
/// @nodoc
class _$ThreadInfoCopyWithImpl<$Res>
    implements $ThreadInfoCopyWith<$Res> {
  _$ThreadInfoCopyWithImpl(this._self, this._then);

  final ThreadInfo _self;
  final $Res Function(ThreadInfo) _then;

/// Create a copy of ThreadInfo
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? replyCount = null,}) {
  return _then(_self.copyWith(
replyCount: null == replyCount ? _self.replyCount : replyCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ThreadInfo].
extension ThreadInfoPatterns on ThreadInfo {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ThreadInfo value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ThreadInfo() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ThreadInfo value)  $default,){
final _that = this;
switch (_that) {
case _ThreadInfo():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ThreadInfo value)?  $default,){
final _that = this;
switch (_that) {
case _ThreadInfo() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int replyCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ThreadInfo() when $default != null:
return $default(_that.replyCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int replyCount)  $default,) {final _that = this;
switch (_that) {
case _ThreadInfo():
return $default(_that.replyCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int replyCount)?  $default,) {final _that = this;
switch (_that) {
case _ThreadInfo() when $default != null:
return $default(_that.replyCount);case _:
  return null;

}
}

}

/// @nodoc


class _ThreadInfo implements ThreadInfo {
  const _ThreadInfo({required this.replyCount});
  

@override final  int replyCount;

/// Create a copy of ThreadInfo
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ThreadInfoCopyWith<_ThreadInfo> get copyWith => __$ThreadInfoCopyWithImpl<_ThreadInfo>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ThreadInfo&&(identical(other.replyCount, replyCount) || other.replyCount == replyCount));
}


@override
int get hashCode => Object.hash(runtimeType,replyCount);

@override
String toString() {
  return 'ThreadInfo(replyCount: $replyCount)';
}


}

/// @nodoc
abstract mixin class _$ThreadInfoCopyWith<$Res> implements $ThreadInfoCopyWith<$Res> {
  factory _$ThreadInfoCopyWith(_ThreadInfo value, $Res Function(_ThreadInfo) _then) = __$ThreadInfoCopyWithImpl;
@override @useResult
$Res call({
 int replyCount
});




}
/// @nodoc
class __$ThreadInfoCopyWithImpl<$Res>
    implements _$ThreadInfoCopyWith<$Res> {
  __$ThreadInfoCopyWithImpl(this._self, this._then);

  final _ThreadInfo _self;
  final $Res Function(_ThreadInfo) _then;

/// Create a copy of ThreadInfo
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? replyCount = null,}) {
  return _then(_ThreadInfo(
replyCount: null == replyCount ? _self.replyCount : replyCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$MessageItem {

 int get id; String? get message; String get messageType; StickerSummary? get sticker; Sender get sender; String get chatId; DateTime? get createdAt; bool get isEdited; bool get isDeleted; String get clientGeneratedId; int? get replyRootId; bool get hasAttachments; ReplyToMessage? get replyToMessage; List<AttachmentItem> get attachments; List<ReactionSummary> get reactions; List<MentionInfo> get mentions; ThreadInfo? get threadInfo;
/// Create a copy of MessageItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageItemCopyWith<MessageItem> get copyWith => _$MessageItemCopyWithImpl<MessageItem>(this as MessageItem, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageItem&&(identical(other.id, id) || other.id == id)&&(identical(other.message, message) || other.message == message)&&(identical(other.messageType, messageType) || other.messageType == messageType)&&(identical(other.sticker, sticker) || other.sticker == sticker)&&(identical(other.sender, sender) || other.sender == sender)&&(identical(other.chatId, chatId) || other.chatId == chatId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.isEdited, isEdited) || other.isEdited == isEdited)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.clientGeneratedId, clientGeneratedId) || other.clientGeneratedId == clientGeneratedId)&&(identical(other.replyRootId, replyRootId) || other.replyRootId == replyRootId)&&(identical(other.hasAttachments, hasAttachments) || other.hasAttachments == hasAttachments)&&(identical(other.replyToMessage, replyToMessage) || other.replyToMessage == replyToMessage)&&const DeepCollectionEquality().equals(other.attachments, attachments)&&const DeepCollectionEquality().equals(other.reactions, reactions)&&const DeepCollectionEquality().equals(other.mentions, mentions)&&(identical(other.threadInfo, threadInfo) || other.threadInfo == threadInfo));
}


@override
int get hashCode => Object.hash(runtimeType,id,message,messageType,sticker,sender,chatId,createdAt,isEdited,isDeleted,clientGeneratedId,replyRootId,hasAttachments,replyToMessage,const DeepCollectionEquality().hash(attachments),const DeepCollectionEquality().hash(reactions),const DeepCollectionEquality().hash(mentions),threadInfo);

@override
String toString() {
  return 'MessageItem(id: $id, message: $message, messageType: $messageType, sticker: $sticker, sender: $sender, chatId: $chatId, createdAt: $createdAt, isEdited: $isEdited, isDeleted: $isDeleted, clientGeneratedId: $clientGeneratedId, replyRootId: $replyRootId, hasAttachments: $hasAttachments, replyToMessage: $replyToMessage, attachments: $attachments, reactions: $reactions, mentions: $mentions, threadInfo: $threadInfo)';
}


}

/// @nodoc
abstract mixin class $MessageItemCopyWith<$Res>  {
  factory $MessageItemCopyWith(MessageItem value, $Res Function(MessageItem) _then) = _$MessageItemCopyWithImpl;
@useResult
$Res call({
 int id, String? message, String messageType, StickerSummary? sticker, Sender sender, String chatId, DateTime? createdAt, bool isEdited, bool isDeleted, String clientGeneratedId, int? replyRootId, bool hasAttachments, ReplyToMessage? replyToMessage, List<AttachmentItem> attachments, List<ReactionSummary> reactions, List<MentionInfo> mentions, ThreadInfo? threadInfo
});


$StickerSummaryCopyWith<$Res>? get sticker;$SenderCopyWith<$Res> get sender;$ReplyToMessageCopyWith<$Res>? get replyToMessage;$ThreadInfoCopyWith<$Res>? get threadInfo;

}
/// @nodoc
class _$MessageItemCopyWithImpl<$Res>
    implements $MessageItemCopyWith<$Res> {
  _$MessageItemCopyWithImpl(this._self, this._then);

  final MessageItem _self;
  final $Res Function(MessageItem) _then;

/// Create a copy of MessageItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? message = freezed,Object? messageType = null,Object? sticker = freezed,Object? sender = null,Object? chatId = null,Object? createdAt = freezed,Object? isEdited = null,Object? isDeleted = null,Object? clientGeneratedId = null,Object? replyRootId = freezed,Object? hasAttachments = null,Object? replyToMessage = freezed,Object? attachments = null,Object? reactions = null,Object? mentions = null,Object? threadInfo = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,messageType: null == messageType ? _self.messageType : messageType // ignore: cast_nullable_to_non_nullable
as String,sticker: freezed == sticker ? _self.sticker : sticker // ignore: cast_nullable_to_non_nullable
as StickerSummary?,sender: null == sender ? _self.sender : sender // ignore: cast_nullable_to_non_nullable
as Sender,chatId: null == chatId ? _self.chatId : chatId // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isEdited: null == isEdited ? _self.isEdited : isEdited // ignore: cast_nullable_to_non_nullable
as bool,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,clientGeneratedId: null == clientGeneratedId ? _self.clientGeneratedId : clientGeneratedId // ignore: cast_nullable_to_non_nullable
as String,replyRootId: freezed == replyRootId ? _self.replyRootId : replyRootId // ignore: cast_nullable_to_non_nullable
as int?,hasAttachments: null == hasAttachments ? _self.hasAttachments : hasAttachments // ignore: cast_nullable_to_non_nullable
as bool,replyToMessage: freezed == replyToMessage ? _self.replyToMessage : replyToMessage // ignore: cast_nullable_to_non_nullable
as ReplyToMessage?,attachments: null == attachments ? _self.attachments : attachments // ignore: cast_nullable_to_non_nullable
as List<AttachmentItem>,reactions: null == reactions ? _self.reactions : reactions // ignore: cast_nullable_to_non_nullable
as List<ReactionSummary>,mentions: null == mentions ? _self.mentions : mentions // ignore: cast_nullable_to_non_nullable
as List<MentionInfo>,threadInfo: freezed == threadInfo ? _self.threadInfo : threadInfo // ignore: cast_nullable_to_non_nullable
as ThreadInfo?,
  ));
}
/// Create a copy of MessageItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StickerSummaryCopyWith<$Res>? get sticker {
    if (_self.sticker == null) {
    return null;
  }

  return $StickerSummaryCopyWith<$Res>(_self.sticker!, (value) {
    return _then(_self.copyWith(sticker: value));
  });
}/// Create a copy of MessageItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SenderCopyWith<$Res> get sender {
  
  return $SenderCopyWith<$Res>(_self.sender, (value) {
    return _then(_self.copyWith(sender: value));
  });
}/// Create a copy of MessageItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReplyToMessageCopyWith<$Res>? get replyToMessage {
    if (_self.replyToMessage == null) {
    return null;
  }

  return $ReplyToMessageCopyWith<$Res>(_self.replyToMessage!, (value) {
    return _then(_self.copyWith(replyToMessage: value));
  });
}/// Create a copy of MessageItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ThreadInfoCopyWith<$Res>? get threadInfo {
    if (_self.threadInfo == null) {
    return null;
  }

  return $ThreadInfoCopyWith<$Res>(_self.threadInfo!, (value) {
    return _then(_self.copyWith(threadInfo: value));
  });
}
}


/// Adds pattern-matching-related methods to [MessageItem].
extension MessageItemPatterns on MessageItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MessageItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MessageItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MessageItem value)  $default,){
final _that = this;
switch (_that) {
case _MessageItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MessageItem value)?  $default,){
final _that = this;
switch (_that) {
case _MessageItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String? message,  String messageType,  StickerSummary? sticker,  Sender sender,  String chatId,  DateTime? createdAt,  bool isEdited,  bool isDeleted,  String clientGeneratedId,  int? replyRootId,  bool hasAttachments,  ReplyToMessage? replyToMessage,  List<AttachmentItem> attachments,  List<ReactionSummary> reactions,  List<MentionInfo> mentions,  ThreadInfo? threadInfo)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MessageItem() when $default != null:
return $default(_that.id,_that.message,_that.messageType,_that.sticker,_that.sender,_that.chatId,_that.createdAt,_that.isEdited,_that.isDeleted,_that.clientGeneratedId,_that.replyRootId,_that.hasAttachments,_that.replyToMessage,_that.attachments,_that.reactions,_that.mentions,_that.threadInfo);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String? message,  String messageType,  StickerSummary? sticker,  Sender sender,  String chatId,  DateTime? createdAt,  bool isEdited,  bool isDeleted,  String clientGeneratedId,  int? replyRootId,  bool hasAttachments,  ReplyToMessage? replyToMessage,  List<AttachmentItem> attachments,  List<ReactionSummary> reactions,  List<MentionInfo> mentions,  ThreadInfo? threadInfo)  $default,) {final _that = this;
switch (_that) {
case _MessageItem():
return $default(_that.id,_that.message,_that.messageType,_that.sticker,_that.sender,_that.chatId,_that.createdAt,_that.isEdited,_that.isDeleted,_that.clientGeneratedId,_that.replyRootId,_that.hasAttachments,_that.replyToMessage,_that.attachments,_that.reactions,_that.mentions,_that.threadInfo);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String? message,  String messageType,  StickerSummary? sticker,  Sender sender,  String chatId,  DateTime? createdAt,  bool isEdited,  bool isDeleted,  String clientGeneratedId,  int? replyRootId,  bool hasAttachments,  ReplyToMessage? replyToMessage,  List<AttachmentItem> attachments,  List<ReactionSummary> reactions,  List<MentionInfo> mentions,  ThreadInfo? threadInfo)?  $default,) {final _that = this;
switch (_that) {
case _MessageItem() when $default != null:
return $default(_that.id,_that.message,_that.messageType,_that.sticker,_that.sender,_that.chatId,_that.createdAt,_that.isEdited,_that.isDeleted,_that.clientGeneratedId,_that.replyRootId,_that.hasAttachments,_that.replyToMessage,_that.attachments,_that.reactions,_that.mentions,_that.threadInfo);case _:
  return null;

}
}

}

/// @nodoc


class _MessageItem implements MessageItem {
  const _MessageItem({required this.id, this.message, required this.messageType, this.sticker, required this.sender, required this.chatId, this.createdAt, this.isEdited = false, this.isDeleted = false, this.clientGeneratedId = '', this.replyRootId, this.hasAttachments = false, this.replyToMessage, final  List<AttachmentItem> attachments = const [], final  List<ReactionSummary> reactions = const [], final  List<MentionInfo> mentions = const [], this.threadInfo}): _attachments = attachments,_reactions = reactions,_mentions = mentions;
  

@override final  int id;
@override final  String? message;
@override final  String messageType;
@override final  StickerSummary? sticker;
@override final  Sender sender;
@override final  String chatId;
@override final  DateTime? createdAt;
@override@JsonKey() final  bool isEdited;
@override@JsonKey() final  bool isDeleted;
@override@JsonKey() final  String clientGeneratedId;
@override final  int? replyRootId;
@override@JsonKey() final  bool hasAttachments;
@override final  ReplyToMessage? replyToMessage;
 final  List<AttachmentItem> _attachments;
@override@JsonKey() List<AttachmentItem> get attachments {
  if (_attachments is EqualUnmodifiableListView) return _attachments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_attachments);
}

 final  List<ReactionSummary> _reactions;
@override@JsonKey() List<ReactionSummary> get reactions {
  if (_reactions is EqualUnmodifiableListView) return _reactions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_reactions);
}

 final  List<MentionInfo> _mentions;
@override@JsonKey() List<MentionInfo> get mentions {
  if (_mentions is EqualUnmodifiableListView) return _mentions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_mentions);
}

@override final  ThreadInfo? threadInfo;

/// Create a copy of MessageItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessageItemCopyWith<_MessageItem> get copyWith => __$MessageItemCopyWithImpl<_MessageItem>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessageItem&&(identical(other.id, id) || other.id == id)&&(identical(other.message, message) || other.message == message)&&(identical(other.messageType, messageType) || other.messageType == messageType)&&(identical(other.sticker, sticker) || other.sticker == sticker)&&(identical(other.sender, sender) || other.sender == sender)&&(identical(other.chatId, chatId) || other.chatId == chatId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.isEdited, isEdited) || other.isEdited == isEdited)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.clientGeneratedId, clientGeneratedId) || other.clientGeneratedId == clientGeneratedId)&&(identical(other.replyRootId, replyRootId) || other.replyRootId == replyRootId)&&(identical(other.hasAttachments, hasAttachments) || other.hasAttachments == hasAttachments)&&(identical(other.replyToMessage, replyToMessage) || other.replyToMessage == replyToMessage)&&const DeepCollectionEquality().equals(other._attachments, _attachments)&&const DeepCollectionEquality().equals(other._reactions, _reactions)&&const DeepCollectionEquality().equals(other._mentions, _mentions)&&(identical(other.threadInfo, threadInfo) || other.threadInfo == threadInfo));
}


@override
int get hashCode => Object.hash(runtimeType,id,message,messageType,sticker,sender,chatId,createdAt,isEdited,isDeleted,clientGeneratedId,replyRootId,hasAttachments,replyToMessage,const DeepCollectionEquality().hash(_attachments),const DeepCollectionEquality().hash(_reactions),const DeepCollectionEquality().hash(_mentions),threadInfo);

@override
String toString() {
  return 'MessageItem(id: $id, message: $message, messageType: $messageType, sticker: $sticker, sender: $sender, chatId: $chatId, createdAt: $createdAt, isEdited: $isEdited, isDeleted: $isDeleted, clientGeneratedId: $clientGeneratedId, replyRootId: $replyRootId, hasAttachments: $hasAttachments, replyToMessage: $replyToMessage, attachments: $attachments, reactions: $reactions, mentions: $mentions, threadInfo: $threadInfo)';
}


}

/// @nodoc
abstract mixin class _$MessageItemCopyWith<$Res> implements $MessageItemCopyWith<$Res> {
  factory _$MessageItemCopyWith(_MessageItem value, $Res Function(_MessageItem) _then) = __$MessageItemCopyWithImpl;
@override @useResult
$Res call({
 int id, String? message, String messageType, StickerSummary? sticker, Sender sender, String chatId, DateTime? createdAt, bool isEdited, bool isDeleted, String clientGeneratedId, int? replyRootId, bool hasAttachments, ReplyToMessage? replyToMessage, List<AttachmentItem> attachments, List<ReactionSummary> reactions, List<MentionInfo> mentions, ThreadInfo? threadInfo
});


@override $StickerSummaryCopyWith<$Res>? get sticker;@override $SenderCopyWith<$Res> get sender;@override $ReplyToMessageCopyWith<$Res>? get replyToMessage;@override $ThreadInfoCopyWith<$Res>? get threadInfo;

}
/// @nodoc
class __$MessageItemCopyWithImpl<$Res>
    implements _$MessageItemCopyWith<$Res> {
  __$MessageItemCopyWithImpl(this._self, this._then);

  final _MessageItem _self;
  final $Res Function(_MessageItem) _then;

/// Create a copy of MessageItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? message = freezed,Object? messageType = null,Object? sticker = freezed,Object? sender = null,Object? chatId = null,Object? createdAt = freezed,Object? isEdited = null,Object? isDeleted = null,Object? clientGeneratedId = null,Object? replyRootId = freezed,Object? hasAttachments = null,Object? replyToMessage = freezed,Object? attachments = null,Object? reactions = null,Object? mentions = null,Object? threadInfo = freezed,}) {
  return _then(_MessageItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,messageType: null == messageType ? _self.messageType : messageType // ignore: cast_nullable_to_non_nullable
as String,sticker: freezed == sticker ? _self.sticker : sticker // ignore: cast_nullable_to_non_nullable
as StickerSummary?,sender: null == sender ? _self.sender : sender // ignore: cast_nullable_to_non_nullable
as Sender,chatId: null == chatId ? _self.chatId : chatId // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isEdited: null == isEdited ? _self.isEdited : isEdited // ignore: cast_nullable_to_non_nullable
as bool,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,clientGeneratedId: null == clientGeneratedId ? _self.clientGeneratedId : clientGeneratedId // ignore: cast_nullable_to_non_nullable
as String,replyRootId: freezed == replyRootId ? _self.replyRootId : replyRootId // ignore: cast_nullable_to_non_nullable
as int?,hasAttachments: null == hasAttachments ? _self.hasAttachments : hasAttachments // ignore: cast_nullable_to_non_nullable
as bool,replyToMessage: freezed == replyToMessage ? _self.replyToMessage : replyToMessage // ignore: cast_nullable_to_non_nullable
as ReplyToMessage?,attachments: null == attachments ? _self._attachments : attachments // ignore: cast_nullable_to_non_nullable
as List<AttachmentItem>,reactions: null == reactions ? _self._reactions : reactions // ignore: cast_nullable_to_non_nullable
as List<ReactionSummary>,mentions: null == mentions ? _self._mentions : mentions // ignore: cast_nullable_to_non_nullable
as List<MentionInfo>,threadInfo: freezed == threadInfo ? _self.threadInfo : threadInfo // ignore: cast_nullable_to_non_nullable
as ThreadInfo?,
  ));
}

/// Create a copy of MessageItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StickerSummaryCopyWith<$Res>? get sticker {
    if (_self.sticker == null) {
    return null;
  }

  return $StickerSummaryCopyWith<$Res>(_self.sticker!, (value) {
    return _then(_self.copyWith(sticker: value));
  });
}/// Create a copy of MessageItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SenderCopyWith<$Res> get sender {
  
  return $SenderCopyWith<$Res>(_self.sender, (value) {
    return _then(_self.copyWith(sender: value));
  });
}/// Create a copy of MessageItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReplyToMessageCopyWith<$Res>? get replyToMessage {
    if (_self.replyToMessage == null) {
    return null;
  }

  return $ReplyToMessageCopyWith<$Res>(_self.replyToMessage!, (value) {
    return _then(_self.copyWith(replyToMessage: value));
  });
}/// Create a copy of MessageItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ThreadInfoCopyWith<$Res>? get threadInfo {
    if (_self.threadInfo == null) {
    return null;
  }

  return $ThreadInfoCopyWith<$Res>(_self.threadInfo!, (value) {
    return _then(_self.copyWith(threadInfo: value));
  });
}
}

/// @nodoc
mixin _$ListMessagesResponse {

 List<MessageItem> get messages; String? get nextCursor; String? get prevCursor;
/// Create a copy of ListMessagesResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ListMessagesResponseCopyWith<ListMessagesResponse> get copyWith => _$ListMessagesResponseCopyWithImpl<ListMessagesResponse>(this as ListMessagesResponse, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ListMessagesResponse&&const DeepCollectionEquality().equals(other.messages, messages)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor)&&(identical(other.prevCursor, prevCursor) || other.prevCursor == prevCursor));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(messages),nextCursor,prevCursor);

@override
String toString() {
  return 'ListMessagesResponse(messages: $messages, nextCursor: $nextCursor, prevCursor: $prevCursor)';
}


}

/// @nodoc
abstract mixin class $ListMessagesResponseCopyWith<$Res>  {
  factory $ListMessagesResponseCopyWith(ListMessagesResponse value, $Res Function(ListMessagesResponse) _then) = _$ListMessagesResponseCopyWithImpl;
@useResult
$Res call({
 List<MessageItem> messages, String? nextCursor, String? prevCursor
});




}
/// @nodoc
class _$ListMessagesResponseCopyWithImpl<$Res>
    implements $ListMessagesResponseCopyWith<$Res> {
  _$ListMessagesResponseCopyWithImpl(this._self, this._then);

  final ListMessagesResponse _self;
  final $Res Function(ListMessagesResponse) _then;

/// Create a copy of ListMessagesResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? messages = null,Object? nextCursor = freezed,Object? prevCursor = freezed,}) {
  return _then(_self.copyWith(
messages: null == messages ? _self.messages : messages // ignore: cast_nullable_to_non_nullable
as List<MessageItem>,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,prevCursor: freezed == prevCursor ? _self.prevCursor : prevCursor // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ListMessagesResponse].
extension ListMessagesResponsePatterns on ListMessagesResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ListMessagesResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ListMessagesResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ListMessagesResponse value)  $default,){
final _that = this;
switch (_that) {
case _ListMessagesResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ListMessagesResponse value)?  $default,){
final _that = this;
switch (_that) {
case _ListMessagesResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<MessageItem> messages,  String? nextCursor,  String? prevCursor)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ListMessagesResponse() when $default != null:
return $default(_that.messages,_that.nextCursor,_that.prevCursor);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<MessageItem> messages,  String? nextCursor,  String? prevCursor)  $default,) {final _that = this;
switch (_that) {
case _ListMessagesResponse():
return $default(_that.messages,_that.nextCursor,_that.prevCursor);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<MessageItem> messages,  String? nextCursor,  String? prevCursor)?  $default,) {final _that = this;
switch (_that) {
case _ListMessagesResponse() when $default != null:
return $default(_that.messages,_that.nextCursor,_that.prevCursor);case _:
  return null;

}
}

}

/// @nodoc


class _ListMessagesResponse implements ListMessagesResponse {
  const _ListMessagesResponse({required final  List<MessageItem> messages, this.nextCursor, this.prevCursor}): _messages = messages;
  

 final  List<MessageItem> _messages;
@override List<MessageItem> get messages {
  if (_messages is EqualUnmodifiableListView) return _messages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_messages);
}

@override final  String? nextCursor;
@override final  String? prevCursor;

/// Create a copy of ListMessagesResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ListMessagesResponseCopyWith<_ListMessagesResponse> get copyWith => __$ListMessagesResponseCopyWithImpl<_ListMessagesResponse>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ListMessagesResponse&&const DeepCollectionEquality().equals(other._messages, _messages)&&(identical(other.nextCursor, nextCursor) || other.nextCursor == nextCursor)&&(identical(other.prevCursor, prevCursor) || other.prevCursor == prevCursor));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_messages),nextCursor,prevCursor);

@override
String toString() {
  return 'ListMessagesResponse(messages: $messages, nextCursor: $nextCursor, prevCursor: $prevCursor)';
}


}

/// @nodoc
abstract mixin class _$ListMessagesResponseCopyWith<$Res> implements $ListMessagesResponseCopyWith<$Res> {
  factory _$ListMessagesResponseCopyWith(_ListMessagesResponse value, $Res Function(_ListMessagesResponse) _then) = __$ListMessagesResponseCopyWithImpl;
@override @useResult
$Res call({
 List<MessageItem> messages, String? nextCursor, String? prevCursor
});




}
/// @nodoc
class __$ListMessagesResponseCopyWithImpl<$Res>
    implements _$ListMessagesResponseCopyWith<$Res> {
  __$ListMessagesResponseCopyWithImpl(this._self, this._then);

  final _ListMessagesResponse _self;
  final $Res Function(_ListMessagesResponse) _then;

/// Create a copy of ListMessagesResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? messages = null,Object? nextCursor = freezed,Object? prevCursor = freezed,}) {
  return _then(_ListMessagesResponse(
messages: null == messages ? _self._messages : messages // ignore: cast_nullable_to_non_nullable
as List<MessageItem>,nextCursor: freezed == nextCursor ? _self.nextCursor : nextCursor // ignore: cast_nullable_to_non_nullable
as String?,prevCursor: freezed == prevCursor ? _self.prevCursor : prevCursor // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
