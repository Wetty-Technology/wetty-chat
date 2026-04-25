// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sender.dart';

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

// dart format on
