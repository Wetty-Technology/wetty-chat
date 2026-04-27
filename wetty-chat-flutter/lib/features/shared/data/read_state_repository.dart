import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chahua/core/api/services/chat_api_service.dart';
import 'package:chahua/core/api/services/thread_api_service.dart';

import '../../chat_list/application/group_list_v2_store.dart';
import '../../conversation/shared/domain/conversation_identity.dart';
import '../../conversation/compose/data/message_api_service_v2.dart';
import '../../../core/notifications/unread_badge_provider.dart';
import 'read_state_models.dart';

enum _ReadReportKind { chat, thread }

typedef _ReadReportTarget = ({_ReadReportKind kind, String id});

class _PendingReadReport {
  _PendingReadReport({
    required this.identity,
    required this.messageId,
    required this.timer,
  });

  final ConversationIdentity identity;
  final int messageId;
  final Timer timer;
}

class ReadStateRepository {
  ReadStateRepository(this.ref) {
    ref.onDispose(dispose);
  }

  static const Duration _readReportDebounce = Duration(milliseconds: 150);

  final Ref ref;
  final Map<_ReadReportTarget, _PendingReadReport> _pendingReports = {};
  final Map<ConversationIdentity, int> _confirmedReadBaseline = {};

  void dispose() {
    for (final pending in _pendingReports.values) {
      pending.timer.cancel();
    }
    _pendingReports.clear();
    _confirmedReadBaseline.clear();
  }

  void resetChatBaselines() {
    _confirmedReadBaseline.removeWhere((identity, _) {
      return identity.threadRootId == null;
    });
  }

  void resetThreadBaselines() {
    _confirmedReadBaseline.removeWhere((identity, _) {
      return identity.threadRootId != null;
    });
  }

  void reportVisibleMessageRead({
    required ConversationIdentity identity,
    required int messageId,
  }) {
    final target = _targetFor(identity);
    final pending = _pendingReports[target];

    final baseline = _confirmedReadBaseline[identity];
    if (baseline != null && messageId <= baseline) {
      log('reportVisibleMessageRead: baseline: $messageId <= $baseline');
      return;
    }

    if (pending != null && messageId <= pending.messageId) {
      log(
        'reportVisibleMessageRead: pending: $messageId <= ${pending.messageId}',
      );
      return;
    }

    log('reportVisibleMessageRead: queueing for $messageId');

    pending?.timer.cancel();
    final timer = Timer(_readReportDebounce, () {
      unawaited(_flushPendingReadReport(target));
    });
    _pendingReports[target] = _PendingReadReport(
      identity: identity,
      messageId: messageId,
      timer: timer,
    );
  }

  Future<ChatReadStateUpdate> markChatRead({
    required String chatId,
    required int messageId,
  }) async {
    final response = await ref
        .read(messageApiServiceV2Provider)
        .markMessagesAsRead(chatId, messageId);
    final parsedChatId = int.tryParse(chatId);
    if (parsedChatId != null) {
      final confirmedMessageId =
          int.tryParse(response.lastReadMessageId ?? '') ?? messageId;
      _confirmedReadBaseline[(chatId: parsedChatId, threadRootId: null)] =
          confirmedMessageId;
    }
    return (
      lastReadMessageId: response.lastReadMessageId,
      unreadCount: response.unreadCount,
    );
  }

  Future<ChatReadStateUpdate> markChatUnread({required String chatId}) async {
    final response = await ref
        .read(chatApiServiceProvider)
        .markChatAsUnread(chatId);
    final parsedChatId = int.tryParse(chatId);
    if (parsedChatId != null) {
      final identity = (chatId: parsedChatId, threadRootId: null);
      _cancelPendingReadReport(_targetFor(identity));
      final lastReadMessageId = int.tryParse(response.lastReadMessageId ?? '');
      if (lastReadMessageId == null) {
        _confirmedReadBaseline.remove(identity);
      } else {
        _confirmedReadBaseline[identity] = lastReadMessageId;
      }
    }
    return (
      lastReadMessageId: response.lastReadMessageId,
      unreadCount: response.unreadCount,
    );
  }

  Future<ThreadReadStateUpdate> markThreadRead({
    required int threadRootId,
    required int messageId,
  }) async {
    final response = await ref
        .read(threadApiServiceProvider)
        .markThreadAsRead(threadRootId, messageId);
    return (updated: response.updated);
  }

  _ReadReportTarget _targetFor(ConversationIdentity identity) {
    final threadRootId = identity.threadRootId;
    if (threadRootId != null) {
      return (kind: _ReadReportKind.thread, id: threadRootId.toString());
    }
    return (kind: _ReadReportKind.chat, id: identity.chatId.toString());
  }

  void _cancelPendingReadReport(_ReadReportTarget target) {
    final pending = _pendingReports.remove(target);
    pending?.timer.cancel();
  }

  Future<void> _flushPendingReadReport(_ReadReportTarget target) async {
    final pending = _pendingReports.remove(target);
    if (pending == null) {
      return;
    }

    pending.timer.cancel();
    final identity = pending.identity;
    final messageId = pending.messageId;

    try {
      switch (target.kind) {
        case _ReadReportKind.chat:
          await _flushChatReadReport(chatId: target.id, messageId: messageId);
        case _ReadReportKind.thread:
          await _flushThreadReadReport(
            identity: identity,
            threadRootId: int.parse(target.id),
            messageId: messageId,
          );
      }
    } catch (error) {
      debugPrint('visible read report failed: $error');
    }
  }

  Future<void> _flushChatReadReport({
    required String chatId,
    required int messageId,
  }) async {
    final response = await markChatRead(chatId: chatId, messageId: messageId);
    ref
        .read(groupListV2StoreProvider.notifier)
        .applyServerReadState(
          chatId: chatId,
          messageId: messageId,
          response: response,
        );
    ref.read(unreadBadgeProvider.notifier).scheduleReconcile();
  }

  Future<void> _flushThreadReadReport({
    required ConversationIdentity identity,
    required int threadRootId,
    required int messageId,
  }) async {
    await markThreadRead(threadRootId: threadRootId, messageId: messageId);
    _confirmedReadBaseline[identity] = messageId;
    ref.read(unreadBadgeProvider.notifier).scheduleReconcile();
  }
}

final readStateRepositoryProvider = Provider<ReadStateRepository>((ref) {
  return ReadStateRepository(ref);
});
