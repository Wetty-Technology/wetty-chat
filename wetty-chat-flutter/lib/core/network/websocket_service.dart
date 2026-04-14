import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../api/client/api_json.dart';
import '../api/models/websocket_api_models.dart';
import '../session/dev_session_store.dart';
import 'api_config.dart';
import 'dio_client.dart';

/// Manages the WebSocket connection.
/// Handles ticket-based auth, keep-alive (pings), and broadcasts events.
class WebSocketService {
  WebSocketChannel? _channel;
  final StreamController<ApiWsEvent> _eventController =
      StreamController<ApiWsEvent>.broadcast();

  Stream<ApiWsEvent> get events => _eventController.stream;

  Timer? _pingTimer;
  Timer? _reconnectTimer;
  bool _isConnecting = false;

  final Dio _dio;

  WebSocketService(this._dio);

  /// Initialize the connection.
  Future<void> init() async {
    if (_isConnecting || (_channel != null)) return;
    _isConnecting = true;
    _reconnectTimer?.cancel();

    try {
      // Fetch auth ticket
      final ticketRes = await _dio.get<Map<String, dynamic>>('/ws/ticket');
      final ticket = WsTicketResponseDto.fromJson(ticketRes.data!).ticket;

      // create a WebSocketChannel
      final wsUrl = '${apiBaseUrl.replaceFirst('http', 'ws')}/ws';
      debugPrint('[WS] connecting to $wsUrl');
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      // Send auth message
      _channel!.sink.add(jsonEncode(WsAuthMessageDto(ticket: ticket).toJson()));

      // Listen for messages
      _channel!.stream.listen(
        (data) {
          developer.log('$data', name: '[ws]');
          try {
            final msg = ApiWsEvent.fromJson(decodeJsonObject(data as String));
            if (msg == null || msg is PongWsEvent) return;
            _eventController.add(msg);
          } catch (_) {
            developer.log('recv malformed payload', name: '[ws]');
            // Drop malformed websocket payloads.
          }
        },
        onError: (error) {
          debugPrint('[WS] error: $error');
          _reconnect();
        },
        onDone: () {
          debugPrint('[WS] connection closed, reconnecting...');
          _reconnect();
        },
      );

      // Start ping loop (every 30 seconds)
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        if (_channel != null) {
          _channel!.sink.add(jsonEncode(const WsPingMessageDto().toJson()));
        }
      });

      debugPrint('[WS] connected');
      _isConnecting = false;
    } catch (e) {
      debugPrint('[WS] init failed: $e');
      _isConnecting = false;
      _reconnect();
    }
  }

  void _reconnect() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    final old = _channel;
    _channel = null;
    old?.sink.close();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      unawaited(init());
    });
  }

  Future<void> refreshSession() async {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    final old = _channel;
    _channel = null;
    await old?.sink.close();
    await init();
  }

  void dispose() {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _eventController.close();
  }
}

final webSocketProvider = Provider<WebSocketService>((ref) {
  final session = ref.watch(authSessionProvider);
  final service = WebSocketService(ref.watch(dioProvider));
  if (session.isAuthenticated) {
    unawaited(service.init());
  }

  // When devSessionProvider changes, Riverpod will recreate this provider,
  // so we dispose the old service.
  ref.onDispose(service.dispose);

  // Listen for subsequent session changes to refresh the connection.
  ref.listen<AuthSessionState>(authSessionProvider, (previous, next) {
    if (previous != null &&
        next.isAuthenticated &&
        !mapEquals(previous.authHeaders, next.authHeaders)) {
      service.refreshSession();
    }
  });

  return service;
});
