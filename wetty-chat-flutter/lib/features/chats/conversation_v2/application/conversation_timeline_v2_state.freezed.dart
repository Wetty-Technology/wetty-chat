// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'conversation_timeline_v2_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ConversationTimelineV2State {

 List<ConversationMessageV2> get beforeMessages; List<ConversationMessageV2> get afterMessages; bool get canLoadOlder; bool get canLoadNewer; bool get isLoadingOlder; bool get isLoadingNewer; bool get isResolvingJump; String? get highlightedStableKey; double get centerViewportFraction; ConversationTimelineV2ViewportCommandKind get viewportCommandKind; int get viewportCommandGeneration; bool get isBootstrapping;
/// Create a copy of ConversationTimelineV2State
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConversationTimelineV2StateCopyWith<ConversationTimelineV2State> get copyWith => _$ConversationTimelineV2StateCopyWithImpl<ConversationTimelineV2State>(this as ConversationTimelineV2State, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConversationTimelineV2State&&const DeepCollectionEquality().equals(other.beforeMessages, beforeMessages)&&const DeepCollectionEquality().equals(other.afterMessages, afterMessages)&&(identical(other.canLoadOlder, canLoadOlder) || other.canLoadOlder == canLoadOlder)&&(identical(other.canLoadNewer, canLoadNewer) || other.canLoadNewer == canLoadNewer)&&(identical(other.isLoadingOlder, isLoadingOlder) || other.isLoadingOlder == isLoadingOlder)&&(identical(other.isLoadingNewer, isLoadingNewer) || other.isLoadingNewer == isLoadingNewer)&&(identical(other.isResolvingJump, isResolvingJump) || other.isResolvingJump == isResolvingJump)&&(identical(other.highlightedStableKey, highlightedStableKey) || other.highlightedStableKey == highlightedStableKey)&&(identical(other.centerViewportFraction, centerViewportFraction) || other.centerViewportFraction == centerViewportFraction)&&(identical(other.viewportCommandKind, viewportCommandKind) || other.viewportCommandKind == viewportCommandKind)&&(identical(other.viewportCommandGeneration, viewportCommandGeneration) || other.viewportCommandGeneration == viewportCommandGeneration)&&(identical(other.isBootstrapping, isBootstrapping) || other.isBootstrapping == isBootstrapping));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(beforeMessages),const DeepCollectionEquality().hash(afterMessages),canLoadOlder,canLoadNewer,isLoadingOlder,isLoadingNewer,isResolvingJump,highlightedStableKey,centerViewportFraction,viewportCommandKind,viewportCommandGeneration,isBootstrapping);

@override
String toString() {
  return 'ConversationTimelineV2State(beforeMessages: $beforeMessages, afterMessages: $afterMessages, canLoadOlder: $canLoadOlder, canLoadNewer: $canLoadNewer, isLoadingOlder: $isLoadingOlder, isLoadingNewer: $isLoadingNewer, isResolvingJump: $isResolvingJump, highlightedStableKey: $highlightedStableKey, centerViewportFraction: $centerViewportFraction, viewportCommandKind: $viewportCommandKind, viewportCommandGeneration: $viewportCommandGeneration, isBootstrapping: $isBootstrapping)';
}


}

/// @nodoc
abstract mixin class $ConversationTimelineV2StateCopyWith<$Res>  {
  factory $ConversationTimelineV2StateCopyWith(ConversationTimelineV2State value, $Res Function(ConversationTimelineV2State) _then) = _$ConversationTimelineV2StateCopyWithImpl;
@useResult
$Res call({
 List<ConversationMessageV2> beforeMessages, List<ConversationMessageV2> afterMessages, bool canLoadOlder, bool canLoadNewer, bool isLoadingOlder, bool isLoadingNewer, bool isResolvingJump, String? highlightedStableKey, double centerViewportFraction, ConversationTimelineV2ViewportCommandKind viewportCommandKind, int viewportCommandGeneration, bool isBootstrapping
});




}
/// @nodoc
class _$ConversationTimelineV2StateCopyWithImpl<$Res>
    implements $ConversationTimelineV2StateCopyWith<$Res> {
  _$ConversationTimelineV2StateCopyWithImpl(this._self, this._then);

  final ConversationTimelineV2State _self;
  final $Res Function(ConversationTimelineV2State) _then;

/// Create a copy of ConversationTimelineV2State
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? beforeMessages = null,Object? afterMessages = null,Object? canLoadOlder = null,Object? canLoadNewer = null,Object? isLoadingOlder = null,Object? isLoadingNewer = null,Object? isResolvingJump = null,Object? highlightedStableKey = freezed,Object? centerViewportFraction = null,Object? viewportCommandKind = null,Object? viewportCommandGeneration = null,Object? isBootstrapping = null,}) {
  return _then(_self.copyWith(
beforeMessages: null == beforeMessages ? _self.beforeMessages : beforeMessages // ignore: cast_nullable_to_non_nullable
as List<ConversationMessageV2>,afterMessages: null == afterMessages ? _self.afterMessages : afterMessages // ignore: cast_nullable_to_non_nullable
as List<ConversationMessageV2>,canLoadOlder: null == canLoadOlder ? _self.canLoadOlder : canLoadOlder // ignore: cast_nullable_to_non_nullable
as bool,canLoadNewer: null == canLoadNewer ? _self.canLoadNewer : canLoadNewer // ignore: cast_nullable_to_non_nullable
as bool,isLoadingOlder: null == isLoadingOlder ? _self.isLoadingOlder : isLoadingOlder // ignore: cast_nullable_to_non_nullable
as bool,isLoadingNewer: null == isLoadingNewer ? _self.isLoadingNewer : isLoadingNewer // ignore: cast_nullable_to_non_nullable
as bool,isResolvingJump: null == isResolvingJump ? _self.isResolvingJump : isResolvingJump // ignore: cast_nullable_to_non_nullable
as bool,highlightedStableKey: freezed == highlightedStableKey ? _self.highlightedStableKey : highlightedStableKey // ignore: cast_nullable_to_non_nullable
as String?,centerViewportFraction: null == centerViewportFraction ? _self.centerViewportFraction : centerViewportFraction // ignore: cast_nullable_to_non_nullable
as double,viewportCommandKind: null == viewportCommandKind ? _self.viewportCommandKind : viewportCommandKind // ignore: cast_nullable_to_non_nullable
as ConversationTimelineV2ViewportCommandKind,viewportCommandGeneration: null == viewportCommandGeneration ? _self.viewportCommandGeneration : viewportCommandGeneration // ignore: cast_nullable_to_non_nullable
as int,isBootstrapping: null == isBootstrapping ? _self.isBootstrapping : isBootstrapping // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ConversationTimelineV2State].
extension ConversationTimelineV2StatePatterns on ConversationTimelineV2State {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConversationTimelineV2State value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConversationTimelineV2State() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConversationTimelineV2State value)  $default,){
final _that = this;
switch (_that) {
case _ConversationTimelineV2State():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConversationTimelineV2State value)?  $default,){
final _that = this;
switch (_that) {
case _ConversationTimelineV2State() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<ConversationMessageV2> beforeMessages,  List<ConversationMessageV2> afterMessages,  bool canLoadOlder,  bool canLoadNewer,  bool isLoadingOlder,  bool isLoadingNewer,  bool isResolvingJump,  String? highlightedStableKey,  double centerViewportFraction,  ConversationTimelineV2ViewportCommandKind viewportCommandKind,  int viewportCommandGeneration,  bool isBootstrapping)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConversationTimelineV2State() when $default != null:
return $default(_that.beforeMessages,_that.afterMessages,_that.canLoadOlder,_that.canLoadNewer,_that.isLoadingOlder,_that.isLoadingNewer,_that.isResolvingJump,_that.highlightedStableKey,_that.centerViewportFraction,_that.viewportCommandKind,_that.viewportCommandGeneration,_that.isBootstrapping);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<ConversationMessageV2> beforeMessages,  List<ConversationMessageV2> afterMessages,  bool canLoadOlder,  bool canLoadNewer,  bool isLoadingOlder,  bool isLoadingNewer,  bool isResolvingJump,  String? highlightedStableKey,  double centerViewportFraction,  ConversationTimelineV2ViewportCommandKind viewportCommandKind,  int viewportCommandGeneration,  bool isBootstrapping)  $default,) {final _that = this;
switch (_that) {
case _ConversationTimelineV2State():
return $default(_that.beforeMessages,_that.afterMessages,_that.canLoadOlder,_that.canLoadNewer,_that.isLoadingOlder,_that.isLoadingNewer,_that.isResolvingJump,_that.highlightedStableKey,_that.centerViewportFraction,_that.viewportCommandKind,_that.viewportCommandGeneration,_that.isBootstrapping);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<ConversationMessageV2> beforeMessages,  List<ConversationMessageV2> afterMessages,  bool canLoadOlder,  bool canLoadNewer,  bool isLoadingOlder,  bool isLoadingNewer,  bool isResolvingJump,  String? highlightedStableKey,  double centerViewportFraction,  ConversationTimelineV2ViewportCommandKind viewportCommandKind,  int viewportCommandGeneration,  bool isBootstrapping)?  $default,) {final _that = this;
switch (_that) {
case _ConversationTimelineV2State() when $default != null:
return $default(_that.beforeMessages,_that.afterMessages,_that.canLoadOlder,_that.canLoadNewer,_that.isLoadingOlder,_that.isLoadingNewer,_that.isResolvingJump,_that.highlightedStableKey,_that.centerViewportFraction,_that.viewportCommandKind,_that.viewportCommandGeneration,_that.isBootstrapping);case _:
  return null;

}
}

}

/// @nodoc


class _ConversationTimelineV2State implements ConversationTimelineV2State {
  const _ConversationTimelineV2State({final  List<ConversationMessageV2> beforeMessages = const <ConversationMessageV2>[], final  List<ConversationMessageV2> afterMessages = const <ConversationMessageV2>[], this.canLoadOlder = false, this.canLoadNewer = false, this.isLoadingOlder = false, this.isLoadingNewer = false, this.isResolvingJump = false, this.highlightedStableKey, this.centerViewportFraction = 1.0, this.viewportCommandKind = ConversationTimelineV2ViewportCommandKind.none, this.viewportCommandGeneration = 0, this.isBootstrapping = true}): _beforeMessages = beforeMessages,_afterMessages = afterMessages;
  

 final  List<ConversationMessageV2> _beforeMessages;
@override@JsonKey() List<ConversationMessageV2> get beforeMessages {
  if (_beforeMessages is EqualUnmodifiableListView) return _beforeMessages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_beforeMessages);
}

 final  List<ConversationMessageV2> _afterMessages;
@override@JsonKey() List<ConversationMessageV2> get afterMessages {
  if (_afterMessages is EqualUnmodifiableListView) return _afterMessages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_afterMessages);
}

@override@JsonKey() final  bool canLoadOlder;
@override@JsonKey() final  bool canLoadNewer;
@override@JsonKey() final  bool isLoadingOlder;
@override@JsonKey() final  bool isLoadingNewer;
@override@JsonKey() final  bool isResolvingJump;
@override final  String? highlightedStableKey;
@override@JsonKey() final  double centerViewportFraction;
@override@JsonKey() final  ConversationTimelineV2ViewportCommandKind viewportCommandKind;
@override@JsonKey() final  int viewportCommandGeneration;
@override@JsonKey() final  bool isBootstrapping;

/// Create a copy of ConversationTimelineV2State
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConversationTimelineV2StateCopyWith<_ConversationTimelineV2State> get copyWith => __$ConversationTimelineV2StateCopyWithImpl<_ConversationTimelineV2State>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConversationTimelineV2State&&const DeepCollectionEquality().equals(other._beforeMessages, _beforeMessages)&&const DeepCollectionEquality().equals(other._afterMessages, _afterMessages)&&(identical(other.canLoadOlder, canLoadOlder) || other.canLoadOlder == canLoadOlder)&&(identical(other.canLoadNewer, canLoadNewer) || other.canLoadNewer == canLoadNewer)&&(identical(other.isLoadingOlder, isLoadingOlder) || other.isLoadingOlder == isLoadingOlder)&&(identical(other.isLoadingNewer, isLoadingNewer) || other.isLoadingNewer == isLoadingNewer)&&(identical(other.isResolvingJump, isResolvingJump) || other.isResolvingJump == isResolvingJump)&&(identical(other.highlightedStableKey, highlightedStableKey) || other.highlightedStableKey == highlightedStableKey)&&(identical(other.centerViewportFraction, centerViewportFraction) || other.centerViewportFraction == centerViewportFraction)&&(identical(other.viewportCommandKind, viewportCommandKind) || other.viewportCommandKind == viewportCommandKind)&&(identical(other.viewportCommandGeneration, viewportCommandGeneration) || other.viewportCommandGeneration == viewportCommandGeneration)&&(identical(other.isBootstrapping, isBootstrapping) || other.isBootstrapping == isBootstrapping));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_beforeMessages),const DeepCollectionEquality().hash(_afterMessages),canLoadOlder,canLoadNewer,isLoadingOlder,isLoadingNewer,isResolvingJump,highlightedStableKey,centerViewportFraction,viewportCommandKind,viewportCommandGeneration,isBootstrapping);

@override
String toString() {
  return 'ConversationTimelineV2State(beforeMessages: $beforeMessages, afterMessages: $afterMessages, canLoadOlder: $canLoadOlder, canLoadNewer: $canLoadNewer, isLoadingOlder: $isLoadingOlder, isLoadingNewer: $isLoadingNewer, isResolvingJump: $isResolvingJump, highlightedStableKey: $highlightedStableKey, centerViewportFraction: $centerViewportFraction, viewportCommandKind: $viewportCommandKind, viewportCommandGeneration: $viewportCommandGeneration, isBootstrapping: $isBootstrapping)';
}


}

/// @nodoc
abstract mixin class _$ConversationTimelineV2StateCopyWith<$Res> implements $ConversationTimelineV2StateCopyWith<$Res> {
  factory _$ConversationTimelineV2StateCopyWith(_ConversationTimelineV2State value, $Res Function(_ConversationTimelineV2State) _then) = __$ConversationTimelineV2StateCopyWithImpl;
@override @useResult
$Res call({
 List<ConversationMessageV2> beforeMessages, List<ConversationMessageV2> afterMessages, bool canLoadOlder, bool canLoadNewer, bool isLoadingOlder, bool isLoadingNewer, bool isResolvingJump, String? highlightedStableKey, double centerViewportFraction, ConversationTimelineV2ViewportCommandKind viewportCommandKind, int viewportCommandGeneration, bool isBootstrapping
});




}
/// @nodoc
class __$ConversationTimelineV2StateCopyWithImpl<$Res>
    implements _$ConversationTimelineV2StateCopyWith<$Res> {
  __$ConversationTimelineV2StateCopyWithImpl(this._self, this._then);

  final _ConversationTimelineV2State _self;
  final $Res Function(_ConversationTimelineV2State) _then;

/// Create a copy of ConversationTimelineV2State
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? beforeMessages = null,Object? afterMessages = null,Object? canLoadOlder = null,Object? canLoadNewer = null,Object? isLoadingOlder = null,Object? isLoadingNewer = null,Object? isResolvingJump = null,Object? highlightedStableKey = freezed,Object? centerViewportFraction = null,Object? viewportCommandKind = null,Object? viewportCommandGeneration = null,Object? isBootstrapping = null,}) {
  return _then(_ConversationTimelineV2State(
beforeMessages: null == beforeMessages ? _self._beforeMessages : beforeMessages // ignore: cast_nullable_to_non_nullable
as List<ConversationMessageV2>,afterMessages: null == afterMessages ? _self._afterMessages : afterMessages // ignore: cast_nullable_to_non_nullable
as List<ConversationMessageV2>,canLoadOlder: null == canLoadOlder ? _self.canLoadOlder : canLoadOlder // ignore: cast_nullable_to_non_nullable
as bool,canLoadNewer: null == canLoadNewer ? _self.canLoadNewer : canLoadNewer // ignore: cast_nullable_to_non_nullable
as bool,isLoadingOlder: null == isLoadingOlder ? _self.isLoadingOlder : isLoadingOlder // ignore: cast_nullable_to_non_nullable
as bool,isLoadingNewer: null == isLoadingNewer ? _self.isLoadingNewer : isLoadingNewer // ignore: cast_nullable_to_non_nullable
as bool,isResolvingJump: null == isResolvingJump ? _self.isResolvingJump : isResolvingJump // ignore: cast_nullable_to_non_nullable
as bool,highlightedStableKey: freezed == highlightedStableKey ? _self.highlightedStableKey : highlightedStableKey // ignore: cast_nullable_to_non_nullable
as String?,centerViewportFraction: null == centerViewportFraction ? _self.centerViewportFraction : centerViewportFraction // ignore: cast_nullable_to_non_nullable
as double,viewportCommandKind: null == viewportCommandKind ? _self.viewportCommandKind : viewportCommandKind // ignore: cast_nullable_to_non_nullable
as ConversationTimelineV2ViewportCommandKind,viewportCommandGeneration: null == viewportCommandGeneration ? _self.viewportCommandGeneration : viewportCommandGeneration // ignore: cast_nullable_to_non_nullable
as int,isBootstrapping: null == isBootstrapping ? _self.isBootstrapping : isBootstrapping // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
