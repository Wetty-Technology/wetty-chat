// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'attachment.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
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

// dart format on
