// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'message_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$MessageItem {

 int get id; String? get message; String get messageType; StickerSummary? get sticker; User get sender; String get chatId; DateTime? get createdAt; bool get isEdited; bool get isDeleted; String get clientGeneratedId; int? get replyRootId; bool get hasAttachments; ReplyToMessage? get replyToMessage; List<AttachmentItem> get attachments; List<ReactionSummary> get reactions; List<MentionInfo> get mentions; ThreadInfo? get threadInfo;
/// Create a copy of MessageItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessageItemCopyWith<MessageItem> get copyWith => _$MessageItemCopyWithImpl<MessageItem>(this as MessageItem, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessageItem&&(identical(other.id, id) || other.id == id)&&(identical(other.message, message) || other.message == message)&&(identical(other.messageType, messageType) || other.messageType == messageType)&&(identical(other.sticker, sticker) || other.sticker == sticker)&&(identical(other.sender, sender) || other.sender == sender)&&(identical(other.chatId, chatId) || other.chatId == chatId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.isEdited, isEdited) || other.isEdited == isEdited)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.clientGeneratedId, clientGeneratedId) || other.clientGeneratedId == clientGeneratedId)&&(identical(other.replyRootId, replyRootId) || other.replyRootId == replyRootId)&&(identical(other.hasAttachments, hasAttachments) || other.hasAttachments == hasAttachments)&&(identical(other.replyToMessage, replyToMessage) || other.replyToMessage == replyToMessage)&&const DeepCollectionEquality().equals(other.attachments, attachments)&&const DeepCollectionEquality().equals(other.reactions, reactions)&&const DeepCollectionEquality().equals(other.mentions, mentions)&&(identical(other.threadInfo, threadInfo) || other.threadInfo == threadInfo));
}


@override
int get hashCode => Object.hash(runtimeType,id,message,messageType,sticker,sender,chatId,createdAt,isEdited,isDeleted,clientGeneratedId,replyRootId,hasAttachments,replyToMessage,const DeepCollectionEquality().hash(attachments),const DeepCollectionEquality().hash(reactions),const DeepCollectionEquality().hash(mentions),threadInfo);

@override
String toString() {
  return 'MessageItem(id: $id, message: $message, messageType: $messageType, sticker: $sticker, sender: $sender, chatId: $chatId, createdAt: $createdAt, isEdited: $isEdited, isDeleted: $isDeleted, clientGeneratedId: $clientGeneratedId, replyRootId: $replyRootId, hasAttachments: $hasAttachments, replyToMessage: $replyToMessage, attachments: $attachments, reactions: $reactions, mentions: $mentions, threadInfo: $threadInfo)';
}


}

/// @nodoc
abstract mixin class $MessageItemCopyWith<$Res>  {
  factory $MessageItemCopyWith(MessageItem value, $Res Function(MessageItem) _then) = _$MessageItemCopyWithImpl;
@useResult
$Res call({
 int id, String? message, String messageType, StickerSummary? sticker, User sender, String chatId, DateTime? createdAt, bool isEdited, bool isDeleted, String clientGeneratedId, int? replyRootId, bool hasAttachments, ReplyToMessage? replyToMessage, List<AttachmentItem> attachments, List<ReactionSummary> reactions, List<MentionInfo> mentions, ThreadInfo? threadInfo
});


$StickerSummaryCopyWith<$Res>? get sticker;$UserCopyWith<$Res> get sender;$ReplyToMessageCopyWith<$Res>? get replyToMessage;$ThreadInfoCopyWith<$Res>? get threadInfo;

}
/// @nodoc
class _$MessageItemCopyWithImpl<$Res>
    implements $MessageItemCopyWith<$Res> {
  _$MessageItemCopyWithImpl(this._self, this._then);

  final MessageItem _self;
  final $Res Function(MessageItem) _then;

/// Create a copy of MessageItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? message = freezed,Object? messageType = null,Object? sticker = freezed,Object? sender = null,Object? chatId = null,Object? createdAt = freezed,Object? isEdited = null,Object? isDeleted = null,Object? clientGeneratedId = null,Object? replyRootId = freezed,Object? hasAttachments = null,Object? replyToMessage = freezed,Object? attachments = null,Object? reactions = null,Object? mentions = null,Object? threadInfo = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,messageType: null == messageType ? _self.messageType : messageType // ignore: cast_nullable_to_non_nullable
as String,sticker: freezed == sticker ? _self.sticker : sticker // ignore: cast_nullable_to_non_nullable
as StickerSummary?,sender: null == sender ? _self.sender : sender // ignore: cast_nullable_to_non_nullable
as User,chatId: null == chatId ? _self.chatId : chatId // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isEdited: null == isEdited ? _self.isEdited : isEdited // ignore: cast_nullable_to_non_nullable
as bool,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,clientGeneratedId: null == clientGeneratedId ? _self.clientGeneratedId : clientGeneratedId // ignore: cast_nullable_to_non_nullable
as String,replyRootId: freezed == replyRootId ? _self.replyRootId : replyRootId // ignore: cast_nullable_to_non_nullable
as int?,hasAttachments: null == hasAttachments ? _self.hasAttachments : hasAttachments // ignore: cast_nullable_to_non_nullable
as bool,replyToMessage: freezed == replyToMessage ? _self.replyToMessage : replyToMessage // ignore: cast_nullable_to_non_nullable
as ReplyToMessage?,attachments: null == attachments ? _self.attachments : attachments // ignore: cast_nullable_to_non_nullable
as List<AttachmentItem>,reactions: null == reactions ? _self.reactions : reactions // ignore: cast_nullable_to_non_nullable
as List<ReactionSummary>,mentions: null == mentions ? _self.mentions : mentions // ignore: cast_nullable_to_non_nullable
as List<MentionInfo>,threadInfo: freezed == threadInfo ? _self.threadInfo : threadInfo // ignore: cast_nullable_to_non_nullable
as ThreadInfo?,
  ));
}
/// Create a copy of MessageItem
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
}/// Create a copy of MessageItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserCopyWith<$Res> get sender {
  
  return $UserCopyWith<$Res>(_self.sender, (value) {
    return _then(_self.copyWith(sender: value));
  });
}/// Create a copy of MessageItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReplyToMessageCopyWith<$Res>? get replyToMessage {
    if (_self.replyToMessage == null) {
    return null;
  }

  return $ReplyToMessageCopyWith<$Res>(_self.replyToMessage!, (value) {
    return _then(_self.copyWith(replyToMessage: value));
  });
}/// Create a copy of MessageItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ThreadInfoCopyWith<$Res>? get threadInfo {
    if (_self.threadInfo == null) {
    return null;
  }

  return $ThreadInfoCopyWith<$Res>(_self.threadInfo!, (value) {
    return _then(_self.copyWith(threadInfo: value));
  });
}
}


/// Adds pattern-matching-related methods to [MessageItem].
extension MessageItemPatterns on MessageItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MessageItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MessageItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MessageItem value)  $default,){
final _that = this;
switch (_that) {
case _MessageItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MessageItem value)?  $default,){
final _that = this;
switch (_that) {
case _MessageItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String? message,  String messageType,  StickerSummary? sticker,  User sender,  String chatId,  DateTime? createdAt,  bool isEdited,  bool isDeleted,  String clientGeneratedId,  int? replyRootId,  bool hasAttachments,  ReplyToMessage? replyToMessage,  List<AttachmentItem> attachments,  List<ReactionSummary> reactions,  List<MentionInfo> mentions,  ThreadInfo? threadInfo)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MessageItem() when $default != null:
return $default(_that.id,_that.message,_that.messageType,_that.sticker,_that.sender,_that.chatId,_that.createdAt,_that.isEdited,_that.isDeleted,_that.clientGeneratedId,_that.replyRootId,_that.hasAttachments,_that.replyToMessage,_that.attachments,_that.reactions,_that.mentions,_that.threadInfo);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String? message,  String messageType,  StickerSummary? sticker,  User sender,  String chatId,  DateTime? createdAt,  bool isEdited,  bool isDeleted,  String clientGeneratedId,  int? replyRootId,  bool hasAttachments,  ReplyToMessage? replyToMessage,  List<AttachmentItem> attachments,  List<ReactionSummary> reactions,  List<MentionInfo> mentions,  ThreadInfo? threadInfo)  $default,) {final _that = this;
switch (_that) {
case _MessageItem():
return $default(_that.id,_that.message,_that.messageType,_that.sticker,_that.sender,_that.chatId,_that.createdAt,_that.isEdited,_that.isDeleted,_that.clientGeneratedId,_that.replyRootId,_that.hasAttachments,_that.replyToMessage,_that.attachments,_that.reactions,_that.mentions,_that.threadInfo);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String? message,  String messageType,  StickerSummary? sticker,  User sender,  String chatId,  DateTime? createdAt,  bool isEdited,  bool isDeleted,  String clientGeneratedId,  int? replyRootId,  bool hasAttachments,  ReplyToMessage? replyToMessage,  List<AttachmentItem> attachments,  List<ReactionSummary> reactions,  List<MentionInfo> mentions,  ThreadInfo? threadInfo)?  $default,) {final _that = this;
switch (_that) {
case _MessageItem() when $default != null:
return $default(_that.id,_that.message,_that.messageType,_that.sticker,_that.sender,_that.chatId,_that.createdAt,_that.isEdited,_that.isDeleted,_that.clientGeneratedId,_that.replyRootId,_that.hasAttachments,_that.replyToMessage,_that.attachments,_that.reactions,_that.mentions,_that.threadInfo);case _:
  return null;

}
}

}

/// @nodoc


class _MessageItem implements MessageItem {
  const _MessageItem({required this.id, this.message, required this.messageType, this.sticker, required this.sender, required this.chatId, this.createdAt, this.isEdited = false, this.isDeleted = false, this.clientGeneratedId = '', this.replyRootId, this.hasAttachments = false, this.replyToMessage, final  List<AttachmentItem> attachments = const [], final  List<ReactionSummary> reactions = const [], final  List<MentionInfo> mentions = const [], this.threadInfo}): _attachments = attachments,_reactions = reactions,_mentions = mentions;
  

@override final  int id;
@override final  String? message;
@override final  String messageType;
@override final  StickerSummary? sticker;
@override final  User sender;
@override final  String chatId;
@override final  DateTime? createdAt;
@override@JsonKey() final  bool isEdited;
@override@JsonKey() final  bool isDeleted;
@override@JsonKey() final  String clientGeneratedId;
@override final  int? replyRootId;
@override@JsonKey() final  bool hasAttachments;
@override final  ReplyToMessage? replyToMessage;
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

 final  List<MentionInfo> _mentions;
@override@JsonKey() List<MentionInfo> get mentions {
  if (_mentions is EqualUnmodifiableListView) return _mentions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_mentions);
}

@override final  ThreadInfo? threadInfo;

/// Create a copy of MessageItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessageItemCopyWith<_MessageItem> get copyWith => __$MessageItemCopyWithImpl<_MessageItem>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessageItem&&(identical(other.id, id) || other.id == id)&&(identical(other.message, message) || other.message == message)&&(identical(other.messageType, messageType) || other.messageType == messageType)&&(identical(other.sticker, sticker) || other.sticker == sticker)&&(identical(other.sender, sender) || other.sender == sender)&&(identical(other.chatId, chatId) || other.chatId == chatId)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.isEdited, isEdited) || other.isEdited == isEdited)&&(identical(other.isDeleted, isDeleted) || other.isDeleted == isDeleted)&&(identical(other.clientGeneratedId, clientGeneratedId) || other.clientGeneratedId == clientGeneratedId)&&(identical(other.replyRootId, replyRootId) || other.replyRootId == replyRootId)&&(identical(other.hasAttachments, hasAttachments) || other.hasAttachments == hasAttachments)&&(identical(other.replyToMessage, replyToMessage) || other.replyToMessage == replyToMessage)&&const DeepCollectionEquality().equals(other._attachments, _attachments)&&const DeepCollectionEquality().equals(other._reactions, _reactions)&&const DeepCollectionEquality().equals(other._mentions, _mentions)&&(identical(other.threadInfo, threadInfo) || other.threadInfo == threadInfo));
}


@override
int get hashCode => Object.hash(runtimeType,id,message,messageType,sticker,sender,chatId,createdAt,isEdited,isDeleted,clientGeneratedId,replyRootId,hasAttachments,replyToMessage,const DeepCollectionEquality().hash(_attachments),const DeepCollectionEquality().hash(_reactions),const DeepCollectionEquality().hash(_mentions),threadInfo);

@override
String toString() {
  return 'MessageItem(id: $id, message: $message, messageType: $messageType, sticker: $sticker, sender: $sender, chatId: $chatId, createdAt: $createdAt, isEdited: $isEdited, isDeleted: $isDeleted, clientGeneratedId: $clientGeneratedId, replyRootId: $replyRootId, hasAttachments: $hasAttachments, replyToMessage: $replyToMessage, attachments: $attachments, reactions: $reactions, mentions: $mentions, threadInfo: $threadInfo)';
}


}

/// @nodoc
abstract mixin class _$MessageItemCopyWith<$Res> implements $MessageItemCopyWith<$Res> {
  factory _$MessageItemCopyWith(_MessageItem value, $Res Function(_MessageItem) _then) = __$MessageItemCopyWithImpl;
@override @useResult
$Res call({
 int id, String? message, String messageType, StickerSummary? sticker, User sender, String chatId, DateTime? createdAt, bool isEdited, bool isDeleted, String clientGeneratedId, int? replyRootId, bool hasAttachments, ReplyToMessage? replyToMessage, List<AttachmentItem> attachments, List<ReactionSummary> reactions, List<MentionInfo> mentions, ThreadInfo? threadInfo
});


@override $StickerSummaryCopyWith<$Res>? get sticker;@override $UserCopyWith<$Res> get sender;@override $ReplyToMessageCopyWith<$Res>? get replyToMessage;@override $ThreadInfoCopyWith<$Res>? get threadInfo;

}
/// @nodoc
class __$MessageItemCopyWithImpl<$Res>
    implements _$MessageItemCopyWith<$Res> {
  __$MessageItemCopyWithImpl(this._self, this._then);

  final _MessageItem _self;
  final $Res Function(_MessageItem) _then;

/// Create a copy of MessageItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? message = freezed,Object? messageType = null,Object? sticker = freezed,Object? sender = null,Object? chatId = null,Object? createdAt = freezed,Object? isEdited = null,Object? isDeleted = null,Object? clientGeneratedId = null,Object? replyRootId = freezed,Object? hasAttachments = null,Object? replyToMessage = freezed,Object? attachments = null,Object? reactions = null,Object? mentions = null,Object? threadInfo = freezed,}) {
  return _then(_MessageItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,message: freezed == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String?,messageType: null == messageType ? _self.messageType : messageType // ignore: cast_nullable_to_non_nullable
as String,sticker: freezed == sticker ? _self.sticker : sticker // ignore: cast_nullable_to_non_nullable
as StickerSummary?,sender: null == sender ? _self.sender : sender // ignore: cast_nullable_to_non_nullable
as User,chatId: null == chatId ? _self.chatId : chatId // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,isEdited: null == isEdited ? _self.isEdited : isEdited // ignore: cast_nullable_to_non_nullable
as bool,isDeleted: null == isDeleted ? _self.isDeleted : isDeleted // ignore: cast_nullable_to_non_nullable
as bool,clientGeneratedId: null == clientGeneratedId ? _self.clientGeneratedId : clientGeneratedId // ignore: cast_nullable_to_non_nullable
as String,replyRootId: freezed == replyRootId ? _self.replyRootId : replyRootId // ignore: cast_nullable_to_non_nullable
as int?,hasAttachments: null == hasAttachments ? _self.hasAttachments : hasAttachments // ignore: cast_nullable_to_non_nullable
as bool,replyToMessage: freezed == replyToMessage ? _self.replyToMessage : replyToMessage // ignore: cast_nullable_to_non_nullable
as ReplyToMessage?,attachments: null == attachments ? _self._attachments : attachments // ignore: cast_nullable_to_non_nullable
as List<AttachmentItem>,reactions: null == reactions ? _self._reactions : reactions // ignore: cast_nullable_to_non_nullable
as List<ReactionSummary>,mentions: null == mentions ? _self._mentions : mentions // ignore: cast_nullable_to_non_nullable
as List<MentionInfo>,threadInfo: freezed == threadInfo ? _self.threadInfo : threadInfo // ignore: cast_nullable_to_non_nullable
as ThreadInfo?,
  ));
}

/// Create a copy of MessageItem
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
}/// Create a copy of MessageItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$UserCopyWith<$Res> get sender {
  
  return $UserCopyWith<$Res>(_self.sender, (value) {
    return _then(_self.copyWith(sender: value));
  });
}/// Create a copy of MessageItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReplyToMessageCopyWith<$Res>? get replyToMessage {
    if (_self.replyToMessage == null) {
    return null;
  }

  return $ReplyToMessageCopyWith<$Res>(_self.replyToMessage!, (value) {
    return _then(_self.copyWith(replyToMessage: value));
  });
}/// Create a copy of MessageItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ThreadInfoCopyWith<$Res>? get threadInfo {
    if (_self.threadInfo == null) {
    return null;
  }

  return $ThreadInfoCopyWith<$Res>(_self.threadInfo!, (value) {
    return _then(_self.copyWith(threadInfo: value));
  });
}
}

// dart format on
