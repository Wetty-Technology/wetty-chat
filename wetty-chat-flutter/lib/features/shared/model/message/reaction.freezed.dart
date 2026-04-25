// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reaction.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
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

// dart format on
