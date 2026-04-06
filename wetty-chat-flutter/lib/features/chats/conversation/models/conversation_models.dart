import '../../models/message_models.dart';

sealed class ConversationScope {
  const ConversationScope();

  const factory ConversationScope.chat(String chatId) = ChatConversationScope;
  const factory ConversationScope.thread(String chatId, int threadRootId) =
      ThreadConversationScope;

  String get chatId;

  String get cacheKey => switch (this) {
    ChatConversationScope(:final chatId) => 'chat:$chatId',
    ThreadConversationScope(:final chatId, :final threadRootId) =>
      'thread:$chatId:$threadRootId',
  };
}

class ChatConversationScope extends ConversationScope {
  const ChatConversationScope(this.chatId);

  @override
  final String chatId;
}

class ThreadConversationScope extends ConversationScope {
  const ThreadConversationScope(this.chatId, this.threadRootId);

  @override
  final String chatId;
  final int threadRootId;
}

sealed class LaunchRequest {
  const LaunchRequest();

  const factory LaunchRequest.latest() = LaunchLatestRequest;
  const factory LaunchRequest.unread(int unreadMessageId) = LaunchUnreadRequest;
  const factory LaunchRequest.message(int messageId, {bool highlight}) =
      LaunchMessageRequest;
}

class LaunchLatestRequest extends LaunchRequest {
  const LaunchLatestRequest();
}

class LaunchUnreadRequest extends LaunchRequest {
  const LaunchUnreadRequest(this.unreadMessageId);

  final int unreadMessageId;
}

class LaunchMessageRequest extends LaunchRequest {
  const LaunchMessageRequest(this.messageId, {this.highlight = true});

  final int messageId;
  final bool highlight;
}

enum ConversationDeliveryState { sending, sent, failed, editing, deleting }

class ConversationMessage {
  const ConversationMessage({
    this.serverId,
    this.localId,
    required this.clientGeneratedId,
    required this.scope,
    this.message,
    required this.messageType,
    required this.sender,
    required this.createdAt,
    required this.isEdited,
    required this.isDeleted,
    this.replyRootId,
    required this.hasAttachments,
    this.replyToMessage,
    this.attachments = const [],
    this.threadInfo,
    this.deliveryState = ConversationDeliveryState.sent,
  });

  final int? serverId;
  final String? localId;
  final String clientGeneratedId;
  final ConversationScope scope;
  final String? message;
  final String messageType;
  final Sender sender;
  final DateTime? createdAt;
  final bool isEdited;
  final bool isDeleted;
  final int? replyRootId;
  final bool hasAttachments;
  final ReplyToMessage? replyToMessage;
  final List<AttachmentItem> attachments;
  final ThreadInfo? threadInfo;
  final ConversationDeliveryState deliveryState;

  String get stableKey =>
      serverId != null ? 'server:$serverId' : 'local:$localId';

  bool get isPending => deliveryState == ConversationDeliveryState.sending;

  ConversationMessage copyWith({
    Object? serverId = _sentinel,
    Object? localId = _sentinel,
    String? clientGeneratedId,
    ConversationScope? scope,
    Object? message = _sentinel,
    String? messageType,
    Sender? sender,
    Object? createdAt = _sentinel,
    bool? isEdited,
    bool? isDeleted,
    Object? replyRootId = _sentinel,
    bool? hasAttachments,
    Object? replyToMessage = _sentinel,
    List<AttachmentItem>? attachments,
    Object? threadInfo = _sentinel,
    ConversationDeliveryState? deliveryState,
  }) {
    return ConversationMessage(
      serverId: serverId == _sentinel ? this.serverId : serverId as int?,
      localId: localId == _sentinel ? this.localId : localId as String?,
      clientGeneratedId: clientGeneratedId ?? this.clientGeneratedId,
      scope: scope ?? this.scope,
      message: message == _sentinel ? this.message : message as String?,
      messageType: messageType ?? this.messageType,
      sender: sender ?? this.sender,
      createdAt: createdAt == _sentinel
          ? this.createdAt
          : createdAt as DateTime?,
      isEdited: isEdited ?? this.isEdited,
      isDeleted: isDeleted ?? this.isDeleted,
      replyRootId: replyRootId == _sentinel
          ? this.replyRootId
          : replyRootId as int?,
      hasAttachments: hasAttachments ?? this.hasAttachments,
      replyToMessage: replyToMessage == _sentinel
          ? this.replyToMessage
          : replyToMessage as ReplyToMessage?,
      attachments: attachments ?? this.attachments,
      threadInfo: threadInfo == _sentinel
          ? this.threadInfo
          : threadInfo as ThreadInfo?,
      deliveryState: deliveryState ?? this.deliveryState,
    );
  }
}

sealed class TimelineEntry {
  const TimelineEntry({required this.key});

  final String key;
}

class TimelineMessageEntry extends TimelineEntry {
  const TimelineMessageEntry({required this.message})
    : super(key: 'message:${message.stableKey}');

  final ConversationMessage message;
}

class TimelineDateSeparatorEntry extends TimelineEntry {
  const TimelineDateSeparatorEntry({required this.date, required super.key});

  final DateTime date;
}

class TimelineUnreadMarkerEntry extends TimelineEntry {
  const TimelineUnreadMarkerEntry() : super(key: 'meta:unread');
}

class TimelineHistoryGapOlderEntry extends TimelineEntry {
  const TimelineHistoryGapOlderEntry() : super(key: 'meta:gap:older');
}

class TimelineHistoryGapNewerEntry extends TimelineEntry {
  const TimelineHistoryGapNewerEntry() : super(key: 'meta:gap:newer');
}

class TimelineLoadingOlderEntry extends TimelineEntry {
  const TimelineLoadingOlderEntry() : super(key: 'meta:loading:older');
}

class TimelineLoadingNewerEntry extends TimelineEntry {
  const TimelineLoadingNewerEntry() : super(key: 'meta:loading:newer');
}

class TimelineWindow {
  const TimelineWindow({
    required this.messages,
    required this.hasOlder,
    required this.hasNewer,
    this.anchorMessageId,
  });

  final List<ConversationMessage> messages;
  final bool hasOlder;
  final bool hasNewer;
  final int? anchorMessageId;
}

class ConversationViewportCache {
  const ConversationViewportCache({
    this.launchRequest = const LaunchLatestRequest(),
    this.anchorMessageId,
    this.visibleMessageIds = const [],
    this.isAtLiveEdge = true,
  });

  final LaunchRequest launchRequest;
  final int? anchorMessageId;
  final List<int> visibleMessageIds;
  final bool isAtLiveEdge;
}

class AnchoredLoadSpec {
  const AnchoredLoadSpec({
    required this.anchorMessageId,
    required this.insertUnreadMarker,
    required this.highlightTarget,
  });

  final int anchorMessageId;
  final bool insertUnreadMarker;
  final bool highlightTarget;
}

const _sentinel = Object();
