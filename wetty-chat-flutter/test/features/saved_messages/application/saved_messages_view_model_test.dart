import 'dart:async';
import 'dart:collection';

import 'package:chahua/core/api/models/saved_messages_api_models.dart';
import 'package:chahua/core/api/services/saved_messages_api_service.dart';
import 'package:chahua/features/saved_messages/application/saved_messages_view_model.dart';
import 'package:chahua/features/saved_messages/domain/saved_messages_scope.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SavedMessagesViewModel', () {
    test('loads global saved messages on build', () async {
      final api = _FakeSavedMessagesApiService(
        responses: [
          ListSavedMessagesResponseDto(
            savedMessages: [_savedMessage(10)],
            nextCursor: 9,
          ),
        ],
      );
      final container = _container(api);
      addTearDown(container.dispose);

      final state = await container.read(
        savedMessagesViewModelProvider(
          const SavedMessagesScope.global(),
        ).future,
      );

      expect(api.requests, [
        const _ListRequest(scope: 'global', limit: 25, before: null),
      ]);
      expect(state.savedMessages.map((message) => message.id), [10]);
      expect(state.nextCursor, 9);
      expect(state.hasMore, isTrue);
    });

    test('loads chat-scoped saved messages on build', () async {
      final api = _FakeSavedMessagesApiService(
        responses: [
          ListSavedMessagesResponseDto(savedMessages: [_savedMessage(11)]),
        ],
      );
      final container = _container(api);
      addTearDown(container.dispose);

      await container.read(
        savedMessagesViewModelProvider(
          const SavedMessagesScope.chat(42),
        ).future,
      );

      expect(api.requests, [
        const _ListRequest(scope: 'chat:42', limit: 25, before: null),
      ]);
    });

    test('loadMore appends the next cursor page', () async {
      final api = _FakeSavedMessagesApiService(
        responses: [
          ListSavedMessagesResponseDto(
            savedMessages: [_savedMessage(1)],
            nextCursor: 1,
          ),
          ListSavedMessagesResponseDto(savedMessages: [_savedMessage(2)]),
        ],
      );
      final container = _container(api);
      addTearDown(container.dispose);
      final provider = savedMessagesViewModelProvider(
        const SavedMessagesScope.global(),
      );

      await container.read(provider.future);
      await container.read(provider.notifier).loadMore();

      final state = container.read(provider).value!;
      expect(api.requests, [
        const _ListRequest(scope: 'global', limit: 25, before: null),
        const _ListRequest(scope: 'global', limit: 25, before: 1),
      ]);
      expect(state.savedMessages.map((message) => message.id), [1, 2]);
      expect(state.hasMore, isFalse);
    });

    test('ignores stale loadMore response after reload', () async {
      final first = Completer<ListSavedMessagesResponseDto>();
      final second = Completer<ListSavedMessagesResponseDto>();
      final reload = Completer<ListSavedMessagesResponseDto>();
      final api = _FakeSavedMessagesApiService(
        completers: [first, second, reload],
      );
      final container = _container(api);
      addTearDown(container.dispose);
      final provider = savedMessagesViewModelProvider(
        const SavedMessagesScope.global(),
      );
      final notifier = container.read(provider.notifier);

      final initialFuture = container.read(provider.future);
      first.complete(
        ListSavedMessagesResponseDto(
          savedMessages: [_savedMessage(1)],
          nextCursor: 1,
        ),
      );
      await initialFuture;

      final loadMoreFuture = notifier.loadMore();
      final reloadFuture = notifier.reload();
      reload.complete(
        ListSavedMessagesResponseDto(savedMessages: [_savedMessage(3)]),
      );
      await reloadFuture;
      second.complete(
        ListSavedMessagesResponseDto(savedMessages: [_savedMessage(2)]),
      );
      await loadMoreFuture;

      final state = container.read(provider).value!;
      expect(state.savedMessages.map((message) => message.id), [3]);
    });

    test('unsave removes a row and rolls back after failure', () async {
      final api = _FakeSavedMessagesApiService(
        responses: [
          ListSavedMessagesResponseDto(
            savedMessages: [_savedMessage(1), _savedMessage(2)],
          ),
        ],
        failDeleteIds: {1},
      );
      final container = _container(api);
      addTearDown(container.dispose);
      final provider = savedMessagesViewModelProvider(
        const SavedMessagesScope.global(),
      );

      await container.read(provider.future);
      await expectLater(
        container.read(provider.notifier).unsave(1),
        throwsA(isA<StateError>()),
      );
      expect(
        container
            .read(provider)
            .value!
            .savedMessages
            .map((message) => message.id),
        [1, 2],
      );

      await container.read(provider.notifier).unsave(2);
      expect(
        container
            .read(provider)
            .value!
            .savedMessages
            .map((message) => message.id),
        [1],
      );
      expect(api.deletedIds, [1, 2]);
    });
  });
}

ProviderContainer _container(_FakeSavedMessagesApiService api) {
  return ProviderContainer(
    overrides: [savedMessagesApiServiceProvider.overrideWithValue(api)],
  );
}

SavedMessageResponseDto _savedMessage(int id) {
  return SavedMessageResponseDto(
    id: id,
    originalChatId: 42,
    originalMessageId: 100 + id,
    originalSenderUid: 7,
    originalCreatedAt: DateTime.utc(2026, 1, id),
    savedAt: DateTime.utc(2026, 2, id),
    message: 'message $id',
    messageType: 'text',
    sender: const SavedSenderSnapshotDto(uid: 7, name: 'Alice', gender: 0),
    chat: const SavedChatSnapshotDto(id: 42, name: 'General'),
    canLocateContext: true,
  );
}

final class _ListRequest {
  const _ListRequest({
    required this.scope,
    required this.limit,
    required this.before,
  });

  final String scope;
  final int limit;
  final int? before;

  @override
  bool operator ==(Object other) {
    return other is _ListRequest &&
        other.scope == scope &&
        other.limit == limit &&
        other.before == before;
  }

  @override
  int get hashCode => Object.hash(scope, limit, before);

  @override
  String toString() {
    return '_ListRequest(scope: $scope, limit: $limit, before: $before)';
  }
}

class _FakeSavedMessagesApiService extends SavedMessagesApiService {
  _FakeSavedMessagesApiService({
    List<ListSavedMessagesResponseDto> responses = const [],
    List<Completer<ListSavedMessagesResponseDto>> completers = const [],
    this.failDeleteIds = const <int>{},
  }) : _responses = Queue.of(responses),
       _completers = Queue.of(completers),
       super(Dio());

  final Queue<ListSavedMessagesResponseDto> _responses;
  final Queue<Completer<ListSavedMessagesResponseDto>> _completers;
  final Set<int> failDeleteIds;
  final List<_ListRequest> requests = [];
  final List<int> deletedIds = [];

  @override
  Future<ListSavedMessagesResponseDto> listSavedMessages({
    int limit = 25,
    int? before,
  }) {
    requests.add(_ListRequest(scope: 'global', limit: limit, before: before));
    return _nextResponse();
  }

  @override
  Future<ListSavedMessagesResponseDto> listChatSavedMessages(
    int chatId, {
    int limit = 25,
    int? before,
  }) {
    requests.add(
      _ListRequest(scope: 'chat:$chatId', limit: limit, before: before),
    );
    return _nextResponse();
  }

  @override
  Future<void> deleteSavedMessage(int savedMessageId) async {
    deletedIds.add(savedMessageId);
    if (failDeleteIds.contains(savedMessageId)) {
      throw StateError('delete failed');
    }
  }

  Future<ListSavedMessagesResponseDto> _nextResponse() {
    if (_completers.isNotEmpty) {
      return _completers.removeFirst().future;
    }
    if (_responses.isNotEmpty) {
      return Future.value(_responses.removeFirst());
    }
    return Future.value(const ListSavedMessagesResponseDto());
  }
}
