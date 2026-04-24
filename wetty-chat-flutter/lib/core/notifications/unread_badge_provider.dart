import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/models/chats_api_models.dart';
import '../session/dev_session_store.dart';
import '../../features/chats/shared/data/chat_api_service.dart';
import '../../features/chats/threads/data/thread_api_service.dart';
import '../../features/chats/threads/models/thread_api_models.dart';
import 'apns_channel.dart';

class UnreadBadgeState {
  const UnreadBadgeState({
    this.chatUnreadTotal = 0,
    this.threadUnreadTotal = 0,
    this.isRefreshing = false,
  });

  final int chatUnreadTotal;
  final int threadUnreadTotal;
  final bool isRefreshing;

  int get combinedUnreadTotal => chatUnreadTotal + threadUnreadTotal;

  UnreadBadgeState copyWith({
    int? chatUnreadTotal,
    int? threadUnreadTotal,
    bool? isRefreshing,
  }) {
    return UnreadBadgeState(
      chatUnreadTotal: chatUnreadTotal ?? this.chatUnreadTotal,
      threadUnreadTotal: threadUnreadTotal ?? this.threadUnreadTotal,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}

int chatBadgeContribution({
  required int unreadCount,
  required DateTime? mutedUntil,
  DateTime? now,
}) {
  if (unreadCount <= 0) {
    return 0;
  }
  final effectiveNow = now ?? DateTime.now();
  if (mutedUntil != null && mutedUntil.isAfter(effectiveNow)) {
    return 0;
  }
  return unreadCount;
}

class UnreadBadgeNotifier extends Notifier<UnreadBadgeState> {
  Timer? _reconcileTimer;
  bool _isDisposed = false;
  bool _isWritingNativeBadge = false;

  ChatApiService get _chatApi => ref.read(chatApiServiceProvider);
  ThreadApiService get _threadApi => ref.read(threadApiServiceProvider);
  ApnsChannel get _apns => ref.read(apnsChannelProvider);

  @override
  UnreadBadgeState build() {
    _isDisposed = false;

    ref.listen<AuthSessionState>(authSessionProvider, (previous, next) {
      if (!next.isAuthenticated) {
        _reconcileTimer?.cancel();
        _replaceState(const UnreadBadgeState());
        unawaited(_syncNativeBadge(0));
        return;
      }
      if (previous?.isAuthenticated != true) {
        unawaited(refresh());
      }
    });

    ref.onDispose(() {
      _isDisposed = true;
      _reconcileTimer?.cancel();
    });

    if (ref.read(authSessionProvider).isAuthenticated) {
      Future.microtask(refresh);
    }

    return const UnreadBadgeState();
  }

  Future<void> refresh() async {
    if (!ref.read(authSessionProvider).isAuthenticated) {
      return;
    }
    _reconcileTimer?.cancel();
    _replaceState(state.copyWith(isRefreshing: true));
    try {
      final results = await Future.wait([
        _chatApi.fetchUnreadCount(),
        _threadApi.fetchUnreadThreadCount(),
      ]);
      final chatResult = results[0] as UnreadCountResponseDto;
      final threadResult = results[1] as UnreadThreadCountResponseDto;
      if (_isDisposed) {
        return;
      }
      final nextState = state.copyWith(
        chatUnreadTotal: chatResult.unreadCount,
        threadUnreadTotal: threadResult.unreadThreadCount,
        isRefreshing: false,
      );
      _replaceState(nextState);
      await _syncNativeBadge(nextState.combinedUnreadTotal);
    } catch (error, stackTrace) {
      developer.log(
        'Failed to refresh unread badge totals: $error',
        name: 'UnreadBadge',
        stackTrace: stackTrace,
      );
      if (!_isDisposed) {
        _replaceState(state.copyWith(isRefreshing: false));
      }
    }
  }

  void scheduleReconcile({Duration delay = const Duration(milliseconds: 800)}) {
    if (!ref.read(authSessionProvider).isAuthenticated) {
      return;
    }
    _reconcileTimer?.cancel();
    _reconcileTimer = Timer(delay, () => unawaited(refresh()));
  }

  void applyChatUnreadDelta(int delta) {
    if (delta == 0) {
      return;
    }
    _replaceState(
      state.copyWith(
        chatUnreadTotal: _clampUnread(state.chatUnreadTotal + delta),
      ),
    );
  }

  void applyThreadUnreadDelta(int delta) {
    if (delta == 0) {
      return;
    }
    _replaceState(
      state.copyWith(
        threadUnreadTotal: _clampUnread(state.threadUnreadTotal + delta),
      ),
    );
  }

  void replaceThreadUnreadTotal(int totalUnreadCount) {
    _replaceState(
      state.copyWith(threadUnreadTotal: _clampUnread(totalUnreadCount)),
    );
  }

  void _replaceState(UnreadBadgeState next) {
    if (_isDisposed) {
      return;
    }
    final previousCount = state.combinedUnreadTotal;
    state = next;
    final nextCount = next.combinedUnreadTotal;
    if (previousCount != nextCount) {
      unawaited(_syncNativeBadge(nextCount));
    }
  }

  Future<void> _syncNativeBadge(int count) async {
    if (!ref.read(authSessionProvider).isAuthenticated ||
        !_supportsNativeBadge ||
        _isWritingNativeBadge) {
      return;
    }

    _isWritingNativeBadge = true;
    try {
      if (count <= 0) {
        await _apns.clearBadge();
      } else {
        await _apns.setBadge(count);
      }
    } catch (error, stackTrace) {
      developer.log(
        'Failed to sync native badge: $error',
        name: 'UnreadBadge',
        stackTrace: stackTrace,
      );
    } finally {
      _isWritingNativeBadge = false;
    }
  }

  bool get _supportsNativeBadge => !kIsWeb && Platform.isIOS;

  int _clampUnread(int value) => value < 0 ? 0 : value;
}

final unreadBadgeProvider =
    NotifierProvider<UnreadBadgeNotifier, UnreadBadgeState>(
      UnreadBadgeNotifier.new,
    );
