// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reply_to_message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ReplyToMessage {

 int get id; String? get message; String get messageType; StickerSummary? get sticker; User get sender; bool get isDeleted; List<AttachmentItem> get attachments; List<ReactionSummary> get reactions; String? get firstAttachmentKind; List<MentionInfo> get mentions;
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
 int id, String? message, String messageType, StickerSummary? sticker, User sender, bool isDeleted, List<AttachmentItem> attachments, List<ReactionSummary> reactions, String? firstAttachmentKind, List<MentionInfo> mentions
});


$StickerSummaryCopyWith<$Res>? get sticker;$UserCopyWith<$Res> get sender;

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
as User,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
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
$UserCopyWith<$Res> get sender {
  
  return $UserCopyWith<$Res>(_self.sender, (value) {
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String? message,  String messageType,  StickerSummary? sticker,  User sender,  bool isDeleted,  List<AttachmentItem> attachments,  List<ReactionSummary> reactions,  String? firstAttachmentKind,  List<MentionInfo> mentions)?  $default,{required TResult orElse(),}) {final _that = this;
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String? message,  String messageType,  StickerSummary? sticker,  User sender,  bool isDeleted,  List<AttachmentItem> attachments,  List<ReactionSummary> reactions,  String? firstAttachmentKind,  List<MentionInfo> mentions)  $default,) {final _that = this;
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String? message,  String messageType,  StickerSummary? sticker,  User sender,  bool isDeleted,  List<AttachmentItem> attachments,  List<ReactionSummary> reactions,  String? firstAttachmentKind,  List<MentionInfo> mentions)?  $default,) {final _that = this;
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
@override final  User sender;
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
 int id, String? message, String messageType, StickerSummary? sticker, User sender, bool isDeleted, List<AttachmentItem> attachments, List<ReactionSummary> reactions, String? firstAttachmentKind, List<MentionInfo> mentions
});


@override $StickerSummaryCopyWith<$Res>? get sticker;@override $UserCopyWith<$Res> get sender;

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
as User,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
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
$UserCopyWith<$Res> get sender {
  
  return $UserCopyWith<$Res>(_self.sender, (value) {
    return _then(_self.copyWith(sender: value));
  });
}
}

// dart format on
