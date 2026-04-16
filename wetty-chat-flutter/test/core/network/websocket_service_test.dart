import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:chahua/core/api/models/websocket_api_models.dart';
import 'package:chahua/core/network/websocket_service.dart';

void main() {
  group('WebSocketService', () {
    test('lifecycle transition updates cached state', () {
      final service = WebSocketService(Dio());

      service.updateAppState(WsClientAppState.inactive);

      expect(service.appState, WsClientAppState.inactive);
    });

    test(
      'immediate transition sends appState and stateful ping when connected',
      () async {
        final channel = _FakeWebSocketChannel();
        final service = WebSocketService(
          Dio(),
          ticketLoader: () async => 'ticket',
          channelFactory: (_) => channel,
          pingInterval: const Duration(minutes: 1),
        );
        addTearDown(service.dispose);

        await service.init();
        channel.sentMessages.clear();

        service.updateAppState(WsClientAppState.inactive);

        expect(channel.sentMessages.map(_decodeMessage).toList(), [
          {'type': 'appState', 'state': 'inactive'},
          {'type': 'ping', 'state': 'inactive'},
        ]);
      },
    );

    test('repeated same-state transitions are suppressed', () async {
      final channel = _FakeWebSocketChannel();
      final service = WebSocketService(
        Dio(),
        ticketLoader: () async => 'ticket',
        channelFactory: (_) => channel,
        pingInterval: const Duration(minutes: 1),
      );
      addTearDown(service.dispose);

      await service.init();
      channel.sentMessages.clear();

      service.updateAppState(WsClientAppState.active);

      expect(channel.sentMessages, isEmpty);
    });

    test(
      'connect sends the current cached state immediately after auth succeeds',
      () async {
        final channel = _FakeWebSocketChannel();
        final service = WebSocketService(
          Dio(),
          ticketLoader: () async => 'ticket',
          channelFactory: (_) => channel,
          pingInterval: const Duration(minutes: 1),
        );
        addTearDown(service.dispose);

        service.updateAppState(WsClientAppState.inactive);
        await service.init();

        expect(channel.sentMessages.map(_decodeMessage).toList(), [
          {'type': 'auth', 'ticket': 'ticket'},
          {'type': 'appState', 'state': 'inactive'},
          {'type': 'ping', 'state': 'inactive'},
        ]);
      },
    );

    test('periodic ping includes the latest cached state', () async {
      final channel = _FakeWebSocketChannel();
      final service = WebSocketService(
        Dio(),
        ticketLoader: () async => 'ticket',
        channelFactory: (_) => channel,
        pingInterval: const Duration(milliseconds: 20),
      );
      addTearDown(service.dispose);

      service.updateAppState(WsClientAppState.inactive);
      await service.init();
      channel.sentMessages.clear();

      await Future<void>.delayed(const Duration(milliseconds: 35));

      final decodedMessages = channel.sentMessages.map(_decodeMessage).toList();

      expect(decodedMessages, hasLength(1));
      expect(decodedMessages.single['type'], 'ping');
      expect(decodedMessages.single['state'], 'inactive');
    });
  });
}

Map<String, dynamic> _decodeMessage(String message) =>
    jsonDecode(message) as Map<String, dynamic>;

class _FakeWebSocketChannel implements WebSocketChannel {
  final StreamController<dynamic> _incoming =
      StreamController<dynamic>.broadcast();
  late final _FakeWebSocketSink _sink = _FakeWebSocketSink(_sentMessages);
  final List<String> _sentMessages = <String>[];

  List<String> get sentMessages => _sentMessages;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;

  @override
  Future<void> get ready async {}

  @override
  WebSocketSink get sink => _sink;

  @override
  Stream<dynamic> get stream => _incoming.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeWebSocketSink implements WebSocketSink {
  _FakeWebSocketSink(this._sentMessages);

  final List<String> _sentMessages;
  final Completer<void> _done = Completer<void>();

  @override
  Future<void> addStream(Stream stream) async {
    await for (final value in stream) {
      add(value);
    }
  }

  @override
  void add(Object? data) {
    _sentMessages.add(data as String);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    if (!_done.isCompleted) {
      _done.complete();
    }
  }

  @override
  Future<void> get done => _done.future;
}
