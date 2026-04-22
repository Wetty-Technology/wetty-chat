// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'conversation_timeline_v2_canonical_scope.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ConversationTimelineV2CanonicalScope {

 List<ConversationTimelineCanonicalSegment> get segments; bool get hasLatestSegment; bool get hasReachedOldest; List<ConversationMessageV2> get optimisticMessages;
/// Create a copy of ConversationTimelineV2CanonicalScope
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConversationTimelineV2CanonicalScopeCopyWith<ConversationTimelineCanonicalScope> get copyWith => _$ConversationTimelineV2CanonicalScopeCopyWithImpl<ConversationTimelineCanonicalScope>(this as ConversationTimelineCanonicalScope, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConversationTimelineCanonicalScope&&const DeepCollectionEquality().equals(other.segments, segments)&&(identical(other.hasLatestSegment, hasLatestSegment) || other.hasLatestSegment == hasLatestSegment)&&(identical(other.hasReachedOldest, hasReachedOldest) || other.hasReachedOldest == hasReachedOldest)&&const DeepCollectionEquality().equals(other.optimisticMessages, optimisticMessages));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(segments),hasLatestSegment,hasReachedOldest,const DeepCollectionEquality().hash(optimisticMessages));

@override
String toString() {
  return 'ConversationTimelineV2CanonicalScope(segments: $segments, hasLatestSegment: $hasLatestSegment, hasReachedOldest: $hasReachedOldest, optimisticMessages: $optimisticMessages)';
}


}

/// @nodoc
abstract mixin class $ConversationTimelineV2CanonicalScopeCopyWith<$Res>  {
  factory $ConversationTimelineV2CanonicalScopeCopyWith(ConversationTimelineCanonicalScope value, $Res Function(ConversationTimelineCanonicalScope) _then) = _$ConversationTimelineV2CanonicalScopeCopyWithImpl;
@useResult
$Res call({
 List<ConversationTimelineCanonicalSegment> segments, bool hasLatestSegment, bool hasReachedOldest, List<ConversationMessageV2> optimisticMessages
});




}
/// @nodoc
class _$ConversationTimelineV2CanonicalScopeCopyWithImpl<$Res>
    implements $ConversationTimelineV2CanonicalScopeCopyWith<$Res> {
  _$ConversationTimelineV2CanonicalScopeCopyWithImpl(this._self, this._then);

  final ConversationTimelineCanonicalScope _self;
  final $Res Function(ConversationTimelineCanonicalScope) _then;

/// Create a copy of ConversationTimelineV2CanonicalScope
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? segments = null,Object? hasLatestSegment = null,Object? hasReachedOldest = null,Object? optimisticMessages = null,}) {
  return _then(_self.copyWith(
segments: null == segments ? _self.segments : segments // ignore: cast_nullable_to_non_nullable
as List<ConversationTimelineCanonicalSegment>,hasLatestSegment: null == hasLatestSegment ? _self.hasLatestSegment : hasLatestSegment // ignore: cast_nullable_to_non_nullable
as bool,hasReachedOldest: null == hasReachedOldest ? _self.hasReachedOldest : hasReachedOldest // ignore: cast_nullable_to_non_nullable
as bool,optimisticMessages: null == optimisticMessages ? _self.optimisticMessages : optimisticMessages // ignore: cast_nullable_to_non_nullable
as List<ConversationMessageV2>,
  ));
}

}


/// Adds pattern-matching-related methods to [ConversationTimelineCanonicalScope].
extension ConversationTimelineV2CanonicalScopePatterns on ConversationTimelineCanonicalScope {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConversationTimelineV2CanonicalScope value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConversationTimelineV2CanonicalScope() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConversationTimelineV2CanonicalScope value)  $default,){
final _that = this;
switch (_that) {
case _ConversationTimelineV2CanonicalScope():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConversationTimelineV2CanonicalScope value)?  $default,){
final _that = this;
switch (_that) {
case _ConversationTimelineV2CanonicalScope() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<ConversationTimelineCanonicalSegment> segments,  bool hasLatestSegment,  bool hasReachedOldest,  List<ConversationMessageV2> optimisticMessages)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConversationTimelineV2CanonicalScope() when $default != null:
return $default(_that.segments,_that.hasLatestSegment,_that.hasReachedOldest,_that.optimisticMessages);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<ConversationTimelineCanonicalSegment> segments,  bool hasLatestSegment,  bool hasReachedOldest,  List<ConversationMessageV2> optimisticMessages)  $default,) {final _that = this;
switch (_that) {
case _ConversationTimelineV2CanonicalScope():
return $default(_that.segments,_that.hasLatestSegment,_that.hasReachedOldest,_that.optimisticMessages);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<ConversationTimelineCanonicalSegment> segments,  bool hasLatestSegment,  bool hasReachedOldest,  List<ConversationMessageV2> optimisticMessages)?  $default,) {final _that = this;
switch (_that) {
case _ConversationTimelineV2CanonicalScope() when $default != null:
return $default(_that.segments,_that.hasLatestSegment,_that.hasReachedOldest,_that.optimisticMessages);case _:
  return null;

}
}

}

/// @nodoc


class _ConversationTimelineV2CanonicalScope implements ConversationTimelineCanonicalScope {
  const _ConversationTimelineV2CanonicalScope({final  List<ConversationTimelineCanonicalSegment> segments = const <ConversationTimelineCanonicalSegment>[], this.hasLatestSegment = false, this.hasReachedOldest = false, final  List<ConversationMessageV2> optimisticMessages = const <ConversationMessageV2>[]}): _segments = segments,_optimisticMessages = optimisticMessages;


 final  List<ConversationTimelineCanonicalSegment> _segments;
@override@JsonKey() List<ConversationTimelineCanonicalSegment> get segments {
  if (_segments is EqualUnmodifiableListView) return _segments;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_segments);
}

@override@JsonKey() final  bool hasLatestSegment;
@override@JsonKey() final  bool hasReachedOldest;
 final  List<ConversationMessageV2> _optimisticMessages;
@override@JsonKey() List<ConversationMessageV2> get optimisticMessages {
  if (_optimisticMessages is EqualUnmodifiableListView) return _optimisticMessages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_optimisticMessages);
}


/// Create a copy of ConversationTimelineV2CanonicalScope
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConversationTimelineV2CanonicalScopeCopyWith<_ConversationTimelineV2CanonicalScope> get copyWith => __$ConversationTimelineV2CanonicalScopeCopyWithImpl<_ConversationTimelineV2CanonicalScope>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConversationTimelineV2CanonicalScope&&const DeepCollectionEquality().equals(other._segments, _segments)&&(identical(other.hasLatestSegment, hasLatestSegment) || other.hasLatestSegment == hasLatestSegment)&&(identical(other.hasReachedOldest, hasReachedOldest) || other.hasReachedOldest == hasReachedOldest)&&const DeepCollectionEquality().equals(other._optimisticMessages, _optimisticMessages));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_segments),hasLatestSegment,hasReachedOldest,const DeepCollectionEquality().hash(_optimisticMessages));

@override
String toString() {
  return 'ConversationTimelineV2CanonicalScope(segments: $segments, hasLatestSegment: $hasLatestSegment, hasReachedOldest: $hasReachedOldest, optimisticMessages: $optimisticMessages)';
}


}

/// @nodoc
abstract mixin class _$ConversationTimelineV2CanonicalScopeCopyWith<$Res> implements $ConversationTimelineV2CanonicalScopeCopyWith<$Res> {
  factory _$ConversationTimelineV2CanonicalScopeCopyWith(_ConversationTimelineV2CanonicalScope value, $Res Function(_ConversationTimelineV2CanonicalScope) _then) = __$ConversationTimelineV2CanonicalScopeCopyWithImpl;
@override @useResult
$Res call({
 List<ConversationTimelineCanonicalSegment> segments, bool hasLatestSegment, bool hasReachedOldest, List<ConversationMessageV2> optimisticMessages
});




}
/// @nodoc
class __$ConversationTimelineV2CanonicalScopeCopyWithImpl<$Res>
    implements _$ConversationTimelineV2CanonicalScopeCopyWith<$Res> {
  __$ConversationTimelineV2CanonicalScopeCopyWithImpl(this._self, this._then);

  final _ConversationTimelineV2CanonicalScope _self;
  final $Res Function(_ConversationTimelineV2CanonicalScope) _then;

/// Create a copy of ConversationTimelineV2CanonicalScope
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? segments = null,Object? hasLatestSegment = null,Object? hasReachedOldest = null,Object? optimisticMessages = null,}) {
  return _then(_ConversationTimelineV2CanonicalScope(
segments: null == segments ? _self._segments : segments // ignore: cast_nullable_to_non_nullable
as List<ConversationTimelineCanonicalSegment>,hasLatestSegment: null == hasLatestSegment ? _self.hasLatestSegment : hasLatestSegment // ignore: cast_nullable_to_non_nullable
as bool,hasReachedOldest: null == hasReachedOldest ? _self.hasReachedOldest : hasReachedOldest // ignore: cast_nullable_to_non_nullable
as bool,optimisticMessages: null == optimisticMessages ? _self._optimisticMessages : optimisticMessages // ignore: cast_nullable_to_non_nullable
as List<ConversationMessageV2>,
  ));
}


}

// dart format on
