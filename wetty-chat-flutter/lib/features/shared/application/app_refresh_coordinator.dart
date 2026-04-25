import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chahua/core/session/dev_session_store.dart';
import 'package:chahua/features/conversation/shared/domain/conversation_identity.dart';
import 'package:chahua/features/shared/application/chat_inbox_reconciler.dart';

enum AppRefreshReason {
  appResumed,
  notificationHandled,
  tabReselected,
  userPullToRefresh,
  websocketReconnected,
}

typedef ConversationRecoveryCallback =
    Future<void> Function(AppRefreshReason reason);

class AppRefreshCoordinator {
  AppRefreshCoordinator(this._ref);

  final Ref _ref;
  final Map<ConversationIdentity, ConversationRecoveryCallback>
  _conversationRecoveries = {};

  Future<void>? _inFlightRecovery;

  void registerConversationRecovery({
    required ConversationIdentity identity,
    required ConversationRecoveryCallback recover,
  }) {
    _conversationRecoveries[identity] = recover;
  }

  void unregisterConversationRecovery(ConversationIdentity identity) {
    _conversationRecoveries.remove(identity);
  }

  Future<void> recover(AppRefreshReason reason) {
    final inFlight = _inFlightRecovery;
    if (inFlight != null) {
      return inFlight;
    }

    final recovery = _recover(reason);
    _inFlightRecovery = recovery;
    return recovery.whenComplete(() {
      if (identical(_inFlightRecovery, recovery)) {
        _inFlightRecovery = null;
      }
    });
  }

  Future<void> _recover(AppRefreshReason reason) async {
    if (!_ref.read(authSessionProvider).isAuthenticated) {
      return;
    }

    final conversationRecoveries = _conversationRecoveries.values.toList(
      growable: false,
    );
    await Future.wait([
      _ref
          .read(chatInboxReconcilerProvider)
          .reconcile(
            userInitiated:
                reason == AppRefreshReason.tabReselected ||
                reason == AppRefreshReason.userPullToRefresh,
          ),
      for (final recover in conversationRecoveries) recover(reason),
    ]);
  }
}

final appRefreshCoordinatorProvider = Provider<AppRefreshCoordinator>((ref) {
  return AppRefreshCoordinator(ref);
});
