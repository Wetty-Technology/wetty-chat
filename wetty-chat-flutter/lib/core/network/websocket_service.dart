import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../api/client/api_json.dart';
import '../api/models/websocket_api_models.dart';
import 'api_config.dart';

/// Singleton service to manage the WebSocket connection.
/// Handles ticket-based auth, keep-alive (pings), and broadcasts events.
class WebSocketService {
  static final WebSocketService instance = WebSocketService._internal();
  WebSocketService._internal();

  WebSocketChannel? _channel;
  final StreamController<ApiWsEvent> _eventController =
      StreamController<ApiWsEvent>.broadcast();

  Stream<ApiWsEvent> get events => _eventController.stream;

  Timer? _pingTimer;
  bool _isConnecting = false;

  /// Initialize the connection.
  Future<void> init() async {
    if (_isConnecting || (_channel != null)) return;
    _isConnecting = true;

    try {
      // Fetch auth ticket
      final ticketRes = await http.get(
        Uri.parse('$apiBaseUrl/ws/ticket'),
        headers: apiHeaders,
      );
      if (ticketRes.statusCode != 200) {
        throw Exception('Failed to fetch WS ticket: ${ticketRes.body}');
      }
      final ticket = WsTicketResponseDto.fromJson(
        decodeJsonObject(ticketRes.body),
      ).ticket;

      // create a WebSocketChannel
      final wsUrl = '${apiBaseUrl.replaceAll('http', 'ws')}/ws';
      debugPrint('[WS] connecting to $wsUrl');
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      // Send auth message
      _channel!.sink.add(jsonEncode(WsAuthMessageDto(ticket: ticket).toJson()));

      // Listen for messages
      _channel!.stream.listen(
        (data) {
          try {
            final msg = ApiWsEvent.fromJson(decodeJsonObject(data as String));
            if (msg == null || msg is PongWsEvent) return;
            _eventController.add(msg);
          } catch (_) {
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
    final old = _channel;
    _channel = null;
    old?.sink.close();
    Future.delayed(const Duration(seconds: 5), () => init());
  }

  void dispose() {
    _pingTimer?.cancel();
    _channel?.sink.close();
    _eventController.close();
  }
}
