import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../config/api_config.dart';

/// Singleton service to manage the WebSocket connection.
/// Handles ticket-based auth, keep-alive (pings), and broadcasts events.
class WebSocketService {
  static final WebSocketService instance = WebSocketService._internal();
  WebSocketService._internal();

  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _eventController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get events => _eventController.stream;

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
      final ticket = jsonDecode(ticketRes.body)['ticket'];

      // create a WebSockeChannel
      final wsUrl = apiBaseUrl.replaceAll('http', 'ws') + '/ws';
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      // Send auth message
      _channel!.sink.add(jsonEncode({'type': 'auth', 'ticket': ticket}));

      // Listen for messages
      _channel!.stream.listen(
        (data) {
          try {
            final Map<String, dynamic> msg = jsonDecode(data as String);
            // print("msg: $msg");
            print("msg unread: ${msg['unread_count']}");
            if (msg['type'] == 'pong') {
              // Handle pong if needed
              return;
            }
            _eventController.add(msg);
          } catch (e) {
            print('WS decoding error: $e');
          }
        },
        onError: (e) {
          print('WS error: $e');
          _reconnect();
        },
        onDone: () {
          print('WS connection closed');
          _reconnect();
        },
      );

      // Start ping loop (every 30 seconds)
      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        if (_channel != null) {
          _channel!.sink.add(jsonEncode({'type': 'ping'}));
        }
      });

      _isConnecting = false;
    } catch (e) {
      _isConnecting = false;
      print('WS init failed: $e');
      _reconnect();
    }
  }

  void _reconnect() {
    _channel = null;
    _pingTimer?.cancel();
    // Exponential backoff or simple delay
    Future.delayed(const Duration(seconds: 5), () => init());
  }

  void dispose() {
    _pingTimer?.cancel();
    _channel?.sink.close();
    _eventController.close();
  }
}
