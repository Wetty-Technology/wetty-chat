// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mention.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
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

// dart format on
