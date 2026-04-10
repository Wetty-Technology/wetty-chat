import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chahua/core/api/models/chats_api_models.dart';
import 'package:chahua/core/network/websocket_service.dart';
import 'package:chahua/core/notifications/apns_channel.dart';
import 'package:chahua/core/notifications/unread_badge_provider.dart';
import 'package:chahua/core/session/dev_session_store.dart';
import 'package:chahua/features/chats/list/data/chat_api_service.dart';
import 'package:chahua/features/chats/threads/data/thread_api_service.dart';
import 'package:chahua/features/chats/threads/models/thread_api_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('UnreadBadgeNotifier', () {
    test('refresh combines chat and thread totals', () async {
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(_AuthenticatedSessionNotifier.new),
          chatApiServiceProvider.overrideWithValue(
            _FakeChatApiService(unreadCount: 7),
          ),
          threadApiServiceProvider.overrideWithValue(
            _FakeThreadApiService(unreadCount: 3),
          ),
          apnsChannelProvider.overrideWithValue(_FakeApnsChannel()),
          wsEventsProvider.overrideWith((ref) => const Stream.empty()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(unreadBadgeProvider.notifier).refresh();
      final state = container.read(unreadBadgeProvider);

      expect(state.chatUnreadTotal, 7);
      expect(state.threadUnreadTotal, 3);
      expect(state.combinedUnreadTotal, 10);
      expect(state.isRefreshing, isFalse);
    });

    test('delta helpers update totals without going negative', () {
      final container = ProviderContainer(
        overrides: [
          authSessionProvider.overrideWith(_AuthenticatedSessionNotifier.new),
          chatApiServiceProvider.overrideWithValue(
            _FakeChatApiService(unreadCount: 0),
          ),
          threadApiServiceProvider.overrideWithValue(
            _FakeThreadApiService(unreadCount: 0),
          ),
          apnsChannelProvider.overrideWithValue(_FakeApnsChannel()),
          wsEventsProvider.overrideWith((ref) => const Stream.empty()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(unreadBadgeProvider.notifier);
      notifier.applyChatUnreadDelta(5);
      notifier.applyThreadUnreadDelta(2);
      notifier.applyChatUnreadDelta(-10);

      final state = container.read(unreadBadgeProvider);
      expect(state.chatUnreadTotal, 0);
      expect(state.threadUnreadTotal, 2);
      expect(state.combinedUnreadTotal, 2);
    });
  });

  group('chatBadgeContribution', () {
    test('returns zero for muted chats', () {
      final mutedUntil = DateTime.now().add(const Duration(minutes: 5));

      expect(chatBadgeContribution(unreadCount: 9, mutedUntil: mutedUntil), 0);
    });

    test('returns unread count when chat is not muted', () {
      expect(chatBadgeContribution(unreadCount: 4, mutedUntil: null), 4);
    });
  });
}

class _AuthenticatedSessionNotifier extends AuthSessionNotifier {
  @override
  AuthSessionState build() {
    return const AuthSessionState(
      status: AuthBootstrapStatus.authenticated,
      mode: AuthSessionMode.devHeader,
      developerUserId: 1,
      currentUserId: 1,
    );
  }
}

class _FakeChatApiService extends ChatApiService {
  _FakeChatApiService({required this.unreadCount}) : super(Dio());

  final int unreadCount;

  @override
  Future<UnreadCountResponseDto> fetchUnreadCount() async {
    return UnreadCountResponseDto(unreadCount: unreadCount);
  }
}

class _FakeThreadApiService extends ThreadApiService {
  _FakeThreadApiService({required this.unreadCount}) : super(Dio());

  final int unreadCount;

  @override
  Future<UnreadThreadCountResponseDto> fetchUnreadThreadCount() async {
    return UnreadThreadCountResponseDto(unreadThreadCount: unreadCount);
  }
}

class _FakeApnsChannel extends ApnsChannel {
  @override
  Future<void> clearBadge() async {}

  @override
  Future<void> setBadge(int count) async {}
}
