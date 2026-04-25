// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'thread_list_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ThreadListItem {

 String get chatId; String get chatName; String? get chatAvatar; ConversationMessageV2 get threadRootMessage; List<Sender> get participants; MessagePreview? get lastReply; int get replyCount; DateTime? get lastReplyAt; int get unreadCount; DateTime? get subscribedAt;
/// Create a copy of ThreadListItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ThreadListItemCopyWith<ThreadListItem> get copyWith => _$ThreadListItemCopyWithImpl<ThreadListItem>(this as ThreadListItem, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ThreadListItem&&(identical(other.chatId, chatId) || other.chatId == chatId)&&(identical(other.chatName, chatName) || other.chatName == chatName)&&(identical(other.chatAvatar, chatAvatar) || other.chatAvatar == chatAvatar)&&(identical(other.threadRootMessage, threadRootMessage) || other.threadRootMessage == threadRootMessage)&&const DeepCollectionEquality().equals(other.participants, participants)&&(identical(other.lastReply, lastReply) || other.lastReply == lastReply)&&(identical(other.replyCount, replyCount) || other.replyCount == replyCount)&&(identical(other.lastReplyAt, lastReplyAt) || other.lastReplyAt == lastReplyAt)&&(identical(other.unreadCount, unreadCount) || other.unreadCount == unreadCount)&&(identical(other.subscribedAt, subscribedAt) || other.subscribedAt == subscribedAt));
}


@override
int get hashCode => Object.hash(runtimeType,chatId,chatName,chatAvatar,threadRootMessage,const DeepCollectionEquality().hash(participants),lastReply,replyCount,lastReplyAt,unreadCount,subscribedAt);

@override
String toString() {
  return 'ThreadListItem(chatId: $chatId, chatName: $chatName, chatAvatar: $chatAvatar, threadRootMessage: $threadRootMessage, participants: $participants, lastReply: $lastReply, replyCount: $replyCount, lastReplyAt: $lastReplyAt, unreadCount: $unreadCount, subscribedAt: $subscribedAt)';
}


}

/// @nodoc
abstract mixin class $ThreadListItemCopyWith<$Res>  {
  factory $ThreadListItemCopyWith(ThreadListItem value, $Res Function(ThreadListItem) _then) = _$ThreadListItemCopyWithImpl;
@useResult
$Res call({
 String chatId, String chatName, String? chatAvatar, ConversationMessageV2 threadRootMessage, List<Sender> participants, MessagePreview? lastReply, int replyCount, DateTime? lastReplyAt, int unreadCount, DateTime? subscribedAt
});


$MessagePreviewCopyWith<$Res>? get lastReply;

}
/// @nodoc
class _$ThreadListItemCopyWithImpl<$Res>
    implements $ThreadListItemCopyWith<$Res> {
  _$ThreadListItemCopyWithImpl(this._self, this._then);

  final ThreadListItem _self;
  final $Res Function(ThreadListItem) _then;

/// Create a copy of ThreadListItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? chatId = null,Object? chatName = null,Object? chatAvatar = freezed,Object? threadRootMessage = null,Object? participants = null,Object? lastReply = freezed,Object? replyCount = null,Object? lastReplyAt = freezed,Object? unreadCount = null,Object? subscribedAt = freezed,}) {
  return _then(_self.copyWith(
chatId: null == chatId ? _self.chatId : chatId // ignore: cast_nullable_to_non_nullable
as String,chatName: null == chatName ? _self.chatName : chatName // ignore: cast_nullable_to_non_nullable
as String,chatAvatar: freezed == chatAvatar ? _self.chatAvatar : chatAvatar // ignore: cast_nullable_to_non_nullable
as String?,threadRootMessage: null == threadRootMessage ? _self.threadRootMessage : threadRootMessage // ignore: cast_nullable_to_non_nullable
as ConversationMessageV2,participants: null == participants ? _self.participants : participants // ignore: cast_nullable_to_non_nullable
as List<Sender>,lastReply: freezed == lastReply ? _self.lastReply : lastReply // ignore: cast_nullable_to_non_nullable
as MessagePreview?,replyCount: null == replyCount ? _self.replyCount : replyCount // ignore: cast_nullable_to_non_nullable
as int,lastReplyAt: freezed == lastReplyAt ? _self.lastReplyAt : lastReplyAt // ignore: cast_nullable_to_non_nullable
as DateTime?,unreadCount: null == unreadCount ? _self.unreadCount : unreadCount // ignore: cast_nullable_to_non_nullable
as int,subscribedAt: freezed == subscribedAt ? _self.subscribedAt : subscribedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}
/// Create a copy of ThreadListItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MessagePreviewCopyWith<$Res>? get lastReply {
    if (_self.lastReply == null) {
    return null;
  }

  return $MessagePreviewCopyWith<$Res>(_self.lastReply!, (value) {
    return _then(_self.copyWith(lastReply: value));
  });
}
}


/// Adds pattern-matching-related methods to [ThreadListItem].
extension ThreadListItemPatterns on ThreadListItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ThreadListItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ThreadListItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ThreadListItem value)  $default,){
final _that = this;
switch (_that) {
case _ThreadListItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ThreadListItem value)?  $default,){
final _that = this;
switch (_that) {
case _ThreadListItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String chatId,  String chatName,  String? chatAvatar,  ConversationMessageV2 threadRootMessage,  List<Sender> participants,  MessagePreview? lastReply,  int replyCount,  DateTime? lastReplyAt,  int unreadCount,  DateTime? subscribedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ThreadListItem() when $default != null:
return $default(_that.chatId,_that.chatName,_that.chatAvatar,_that.threadRootMessage,_that.participants,_that.lastReply,_that.replyCount,_that.lastReplyAt,_that.unreadCount,_that.subscribedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String chatId,  String chatName,  String? chatAvatar,  ConversationMessageV2 threadRootMessage,  List<Sender> participants,  MessagePreview? lastReply,  int replyCount,  DateTime? lastReplyAt,  int unreadCount,  DateTime? subscribedAt)  $default,) {final _that = this;
switch (_that) {
case _ThreadListItem():
return $default(_that.chatId,_that.chatName,_that.chatAvatar,_that.threadRootMessage,_that.participants,_that.lastReply,_that.replyCount,_that.lastReplyAt,_that.unreadCount,_that.subscribedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String chatId,  String chatName,  String? chatAvatar,  ConversationMessageV2 threadRootMessage,  List<Sender> participants,  MessagePreview? lastReply,  int replyCount,  DateTime? lastReplyAt,  int unreadCount,  DateTime? subscribedAt)?  $default,) {final _that = this;
switch (_that) {
case _ThreadListItem() when $default != null:
return $default(_that.chatId,_that.chatName,_that.chatAvatar,_that.threadRootMessage,_that.participants,_that.lastReply,_that.replyCount,_that.lastReplyAt,_that.unreadCount,_that.subscribedAt);case _:
  return null;

}
}

}

/// @nodoc


class _ThreadListItem extends ThreadListItem {
  const _ThreadListItem({required this.chatId, required this.chatName, this.chatAvatar, required this.threadRootMessage, final  List<Sender> participants = const [], this.lastReply, this.replyCount = 0, this.lastReplyAt, this.unreadCount = 0, this.subscribedAt}): _participants = participants,super._();
  

@override final  String chatId;
@override final  String chatName;
@override final  String? chatAvatar;
@override final  ConversationMessageV2 threadRootMessage;
 final  List<Sender> _participants;
@override@JsonKey() List<Sender> get participants {
  if (_participants is EqualUnmodifiableListView) return _participants;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_participants);
}

@override final  MessagePreview? lastReply;
@override@JsonKey() final  int replyCount;
@override final  DateTime? lastReplyAt;
@override@JsonKey() final  int unreadCount;
@override final  DateTime? subscribedAt;

/// Create a copy of ThreadListItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ThreadListItemCopyWith<_ThreadListItem> get copyWith => __$ThreadListItemCopyWithImpl<_ThreadListItem>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ThreadListItem&&(identical(other.chatId, chatId) || other.chatId == chatId)&&(identical(other.chatName, chatName) || other.chatName == chatName)&&(identical(other.chatAvatar, chatAvatar) || other.chatAvatar == chatAvatar)&&(identical(other.threadRootMessage, threadRootMessage) || other.threadRootMessage == threadRootMessage)&&const DeepCollectionEquality().equals(other._participants, _participants)&&(identical(other.lastReply, lastReply) || other.lastReply == lastReply)&&(identical(other.replyCount, replyCount) || other.replyCount == replyCount)&&(identical(other.lastReplyAt, lastReplyAt) || other.lastReplyAt == lastReplyAt)&&(identical(other.unreadCount, unreadCount) || other.unreadCount == unreadCount)&&(identical(other.subscribedAt, subscribedAt) || other.subscribedAt == subscribedAt));
}


@override
int get hashCode => Object.hash(runtimeType,chatId,chatName,chatAvatar,threadRootMessage,const DeepCollectionEquality().hash(_participants),lastReply,replyCount,lastReplyAt,unreadCount,subscribedAt);

@override
String toString() {
  return 'ThreadListItem(chatId: $chatId, chatName: $chatName, chatAvatar: $chatAvatar, threadRootMessage: $threadRootMessage, participants: $participants, lastReply: $lastReply, replyCount: $replyCount, lastReplyAt: $lastReplyAt, unreadCount: $unreadCount, subscribedAt: $subscribedAt)';
}


}

/// @nodoc
abstract mixin class _$ThreadListItemCopyWith<$Res> implements $ThreadListItemCopyWith<$Res> {
  factory _$ThreadListItemCopyWith(_ThreadListItem value, $Res Function(_ThreadListItem) _then) = __$ThreadListItemCopyWithImpl;
@override @useResult
$Res call({
 String chatId, String chatName, String? chatAvatar, ConversationMessageV2 threadRootMessage, List<Sender> participants, MessagePreview? lastReply, int replyCount, DateTime? lastReplyAt, int unreadCount, DateTime? subscribedAt
});


@override $MessagePreviewCopyWith<$Res>? get lastReply;

}
/// @nodoc
class __$ThreadListItemCopyWithImpl<$Res>
    implements _$ThreadListItemCopyWith<$Res> {
  __$ThreadListItemCopyWithImpl(this._self, this._then);

  final _ThreadListItem _self;
  final $Res Function(_ThreadListItem) _then;

/// Create a copy of ThreadListItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? chatId = null,Object? chatName = null,Object? chatAvatar = freezed,Object? threadRootMessage = null,Object? participants = null,Object? lastReply = freezed,Object? replyCount = null,Object? lastReplyAt = freezed,Object? unreadCount = null,Object? subscribedAt = freezed,}) {
  return _then(_ThreadListItem(
chatId: null == chatId ? _self.chatId : chatId // ignore: cast_nullable_to_non_nullable
as String,chatName: null == chatName ? _self.chatName : chatName // ignore: cast_nullable_to_non_nullable
as String,chatAvatar: freezed == chatAvatar ? _self.chatAvatar : chatAvatar // ignore: cast_nullable_to_non_nullable
as String?,threadRootMessage: null == threadRootMessage ? _self.threadRootMessage : threadRootMessage // ignore: cast_nullable_to_non_nullable
as ConversationMessageV2,participants: null == participants ? _self._participants : participants // ignore: cast_nullable_to_non_nullable
as List<Sender>,lastReply: freezed == lastReply ? _self.lastReply : lastReply // ignore: cast_nullable_to_non_nullable
as MessagePreview?,replyCount: null == replyCount ? _self.replyCount : replyCount // ignore: cast_nullable_to_non_nullable
as int,lastReplyAt: freezed == lastReplyAt ? _self.lastReplyAt : lastReplyAt // ignore: cast_nullable_to_non_nullable
as DateTime?,unreadCount: null == unreadCount ? _self.unreadCount : unreadCount // ignore: cast_nullable_to_non_nullable
as int,subscribedAt: freezed == subscribedAt ? _self.subscribedAt : subscribedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

/// Create a copy of ThreadListItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MessagePreviewCopyWith<$Res>? get lastReply {
    if (_self.lastReply == null) {
    return null;
  }

  return $MessagePreviewCopyWith<$Res>(_self.lastReply!, (value) {
    return _then(_self.copyWith(lastReply: value));
  });
}
}

// dart format on
