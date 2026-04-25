// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'thread_info.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
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

// dart format on
