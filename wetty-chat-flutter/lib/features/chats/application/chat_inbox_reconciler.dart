import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/unread_badge_provider.dart';
import '../../../core/session/dev_session_store.dart';
import '../list/application/chat_list_view_model.dart';
import '../threads/application/thread_list_view_model.dart';

class ChatInboxReconciler {
  ChatInboxReconciler(this._ref);

  final Ref _ref;

  Future<void> reconcile({bool userInitiated = false}) async {
    if (!_ref.read(authSessionProvider).isAuthenticated) {
      return;
    }

    await Future.wait([
      _refreshChats(userInitiated: userInitiated),
      _refreshThreads(userInitiated: userInitiated),
      _ref.read(unreadBadgeProvider.notifier).refresh(),
    ]);
  }

  Future<void> _refreshChats({required bool userInitiated}) async {
    final current = _ref.read(chatListViewModelProvider).value;
    if (current == null) {
      await _ref.read(chatListViewModelProvider.future);
      return;
    }
    await _ref
        .read(chatListViewModelProvider.notifier)
        .refreshChats(userInitiated: userInitiated);
  }

  Future<void> _refreshThreads({required bool userInitiated}) async {
    final current = _ref.read(threadListViewModelProvider).value;
    if (current == null) {
      await _ref.read(threadListViewModelProvider.future);
      return;
    }
    await _ref
        .read(threadListViewModelProvider.notifier)
        .refreshThreads(userInitiated: userInitiated);
  }
}

final chatInboxReconcilerProvider = Provider<ChatInboxReconciler>((ref) {
  return ChatInboxReconciler(ref);
});
