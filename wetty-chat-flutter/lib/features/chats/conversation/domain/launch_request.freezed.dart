// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'launch_request.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$LaunchRequest {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LaunchRequest);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'LaunchRequest()';
}


}

/// @nodoc
class $LaunchRequestCopyWith<$Res>  {
$LaunchRequestCopyWith(LaunchRequest _, $Res Function(LaunchRequest) __);
}


/// Adds pattern-matching-related methods to [LaunchRequest].
extension LaunchRequestPatterns on LaunchRequest {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( LatestLaunchRequest value)?  latest,TResult Function( UnreadLaunchRequest value)?  unread,TResult Function( MessageLaunchRequest value)?  message,required TResult orElse(),}){
final _that = this;
switch (_that) {
case LatestLaunchRequest() when latest != null:
return latest(_that);case UnreadLaunchRequest() when unread != null:
return unread(_that);case MessageLaunchRequest() when message != null:
return message(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( LatestLaunchRequest value)  latest,required TResult Function( UnreadLaunchRequest value)  unread,required TResult Function( MessageLaunchRequest value)  message,}){
final _that = this;
switch (_that) {
case LatestLaunchRequest():
return latest(_that);case UnreadLaunchRequest():
return unread(_that);case MessageLaunchRequest():
return message(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( LatestLaunchRequest value)?  latest,TResult? Function( UnreadLaunchRequest value)?  unread,TResult? Function( MessageLaunchRequest value)?  message,}){
final _that = this;
switch (_that) {
case LatestLaunchRequest() when latest != null:
return latest(_that);case UnreadLaunchRequest() when unread != null:
return unread(_that);case MessageLaunchRequest() when message != null:
return message(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  latest,TResult Function( int lastReadMessageId)?  unread,TResult Function( int messageId,  bool highlight)?  message,required TResult orElse(),}) {final _that = this;
switch (_that) {
case LatestLaunchRequest() when latest != null:
return latest();case UnreadLaunchRequest() when unread != null:
return unread(_that.lastReadMessageId);case MessageLaunchRequest() when message != null:
return message(_that.messageId,_that.highlight);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  latest,required TResult Function( int lastReadMessageId)  unread,required TResult Function( int messageId,  bool highlight)  message,}) {final _that = this;
switch (_that) {
case LatestLaunchRequest():
return latest();case UnreadLaunchRequest():
return unread(_that.lastReadMessageId);case MessageLaunchRequest():
return message(_that.messageId,_that.highlight);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  latest,TResult? Function( int lastReadMessageId)?  unread,TResult? Function( int messageId,  bool highlight)?  message,}) {final _that = this;
switch (_that) {
case LatestLaunchRequest() when latest != null:
return latest();case UnreadLaunchRequest() when unread != null:
return unread(_that.lastReadMessageId);case MessageLaunchRequest() when message != null:
return message(_that.messageId,_that.highlight);case _:
  return null;

}
}

}

/// @nodoc


class LatestLaunchRequest extends LaunchRequest {
  const LatestLaunchRequest(): super._();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LatestLaunchRequest);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'LaunchRequest.latest()';
}


}




/// @nodoc


class UnreadLaunchRequest extends LaunchRequest {
  const UnreadLaunchRequest({required this.lastReadMessageId}): super._();
  

 final  int lastReadMessageId;

/// Create a copy of LaunchRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UnreadLaunchRequestCopyWith<UnreadLaunchRequest> get copyWith => _$UnreadLaunchRequestCopyWithImpl<UnreadLaunchRequest>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UnreadLaunchRequest&&(identical(other.lastReadMessageId, lastReadMessageId) || other.lastReadMessageId == lastReadMessageId));
}


@override
int get hashCode => Object.hash(runtimeType,lastReadMessageId);

@override
String toString() {
  return 'LaunchRequest.unread(lastReadMessageId: $lastReadMessageId)';
}


}

/// @nodoc
abstract mixin class $UnreadLaunchRequestCopyWith<$Res> implements $LaunchRequestCopyWith<$Res> {
  factory $UnreadLaunchRequestCopyWith(UnreadLaunchRequest value, $Res Function(UnreadLaunchRequest) _then) = _$UnreadLaunchRequestCopyWithImpl;
@useResult
$Res call({
 int lastReadMessageId
});




}
/// @nodoc
class _$UnreadLaunchRequestCopyWithImpl<$Res>
    implements $UnreadLaunchRequestCopyWith<$Res> {
  _$UnreadLaunchRequestCopyWithImpl(this._self, this._then);

  final UnreadLaunchRequest _self;
  final $Res Function(UnreadLaunchRequest) _then;

/// Create a copy of LaunchRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? lastReadMessageId = null,}) {
  return _then(UnreadLaunchRequest(
lastReadMessageId: null == lastReadMessageId ? _self.lastReadMessageId : lastReadMessageId // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class MessageLaunchRequest extends LaunchRequest {
  const MessageLaunchRequest({required this.messageId, this.highlight = true}): super._();
  

 final  int messageId;
@JsonKey() final  bool highlight;

/// Create a copy of LaunchRequest
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageLaunchRequestCopyWith<MessageLaunchRequest> get copyWith => _$MessageLaunchRequestCopyWithImpl<MessageLaunchRequest>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageLaunchRequest&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.highlight, highlight) || other.highlight == highlight));
}


@override
int get hashCode => Object.hash(runtimeType,messageId,highlight);

@override
String toString() {
  return 'LaunchRequest.message(messageId: $messageId, highlight: $highlight)';
}


}

/// @nodoc
abstract mixin class $MessageLaunchRequestCopyWith<$Res> implements $LaunchRequestCopyWith<$Res> {
  factory $MessageLaunchRequestCopyWith(MessageLaunchRequest value, $Res Function(MessageLaunchRequest) _then) = _$MessageLaunchRequestCopyWithImpl;
@useResult
$Res call({
 int messageId, bool highlight
});




}
/// @nodoc
class _$MessageLaunchRequestCopyWithImpl<$Res>
    implements $MessageLaunchRequestCopyWith<$Res> {
  _$MessageLaunchRequestCopyWithImpl(this._self, this._then);

  final MessageLaunchRequest _self;
  final $Res Function(MessageLaunchRequest) _then;

/// Create a copy of LaunchRequest
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? messageId = null,Object? highlight = null,}) {
  return _then(MessageLaunchRequest(
messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as int,highlight: null == highlight ? _self.highlight : highlight // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
