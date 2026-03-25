import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../data/models/message_models.dart';
import 'api_config.dart';
import 'auth_store.dart';

sealed class RealtimeEvent {}

class RealtimeMessageReceived extends RealtimeEvent {
  final MessageItem message;

  RealtimeMessageReceived(this.message);
}

class RealtimeMessageUpdated extends RealtimeEvent {
  final MessageItem message;

  RealtimeMessageUpdated(this.message);
}

class RealtimeMessageDeleted extends RealtimeEvent {
  final MessageItem message;

  RealtimeMessageDeleted(this.message);
}

class RealtimeConnectionChanged extends RealtimeEvent {
  final bool connected;

  RealtimeConnectionChanged(this.connected);
}

class RealtimeService extends ChangeNotifier {
  RealtimeService._();

  static final RealtimeService instance = RealtimeService._();

  final StreamController<RealtimeEvent> _events =
      StreamController<RealtimeEvent>.broadcast();

  WebSocket? _socket;
  StreamSubscription<dynamic>? _socketSubscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  bool _initialized = false;
  bool _isConnecting = false;
  bool _connected = false;
  int _retryAttempt = 0;

  Stream<RealtimeEvent> get events => _events.stream;
  bool get isConnected => _connected;

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[RealtimeService] $message');
    }
  }

  void init() {
    if (_initialized) return;
    _initialized = true;
    _log('init');
    AuthStore.instance.addListener(_handleAuthChanged);
    _handleAuthChanged();
  }

  @override
  void dispose() {
    AuthStore.instance.removeListener(_handleAuthChanged);
    _closeSocket();
    _events.close();
    super.dispose();
  }

  void _handleAuthChanged() {
    _log(
      'auth changed: hasToken=${AuthStore.instance.hasToken} uid=${AuthStore.instance.currentUserId}',
    );
    if (AuthStore.instance.hasToken) {
      unawaited(_connect());
    } else {
      _setConnected(false);
      _closeSocket();
    }
  }

  Future<void> _connect() async {
    if (!_initialized || _isConnecting || _socket != null) {
      _log(
        'skip connect: initialized=$_initialized connecting=$_isConnecting socket=${_socket != null}',
      );
      return;
    }
    if (!AuthStore.instance.hasToken) {
      _log('skip connect: no token');
      return;
    }

    _isConnecting = true;
    _cancelReconnect();
    _log('connecting');

    try {
      final ticket = await _requestWsTicket();
      if (!AuthStore.instance.hasToken) {
        _isConnecting = false;
        _log('connect aborted after ticket: token cleared');
        return;
      }

      final wsUrl = _resolveWsUrl();
      _log('opening socket: $wsUrl');
      final socket = await WebSocket.connect(wsUrl);
      _socket = socket;
      _socketSubscription = socket.listen(
        _handleSocketData,
        onDone: _handleSocketClosed,
        onError: (_) => _handleSocketClosed(),
        cancelOnError: true,
      );

      socket.add(jsonEncode({'type': 'auth', 'ticket': ticket}));
      _startPing();
      _retryAttempt = 0;
      _setConnected(true);
      _log('socket connected and auth message sent');
    } catch (error) {
      _log('connect failed: $error');
      _scheduleReconnect();
    } finally {
      _isConnecting = false;
    }
  }

  Future<String> _requestWsTicket() async {
    final uri = Uri.parse('$apiBaseUrl/ws/ticket');
    _log('requesting ws ticket: $uri');
    final response = await http.get(uri, headers: apiHeaders);
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to request WebSocket ticket: ${response.statusCode} ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final ticket = decoded['ticket'] as String? ?? AuthStore.instance.token!;
    _log('ws ticket acquired');
    return ticket;
  }

  String _resolveWsUrl() {
    final uri = Uri.parse('$apiBaseUrl/ws');
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return uri.replace(scheme: scheme).toString();
  }

  void _handleSocketData(dynamic rawData) {
    if (rawData is! String) return;
    final decoded = jsonDecode(rawData);
    if (decoded is! Map<String, dynamic>) return;

    final type = decoded['type'] as String?;
    final payload = decoded['payload'] as Map<String, dynamic>?;
    if (type == null) return;

    switch (type) {
      case 'pong':
        _log('received pong');
        return;
      case 'message':
        if (payload != null) {
          _log(
            'received message chatId=${payload['chat_id']} id=${payload['id']} replyRoot=${payload['reply_root_id']}',
          );
          _events.add(RealtimeMessageReceived(MessageItem.fromJson(payload)));
        }
        break;
      case 'message_updated':
        if (payload != null) {
          _log(
            'received message_updated chatId=${payload['chat_id']} id=${payload['id']}',
          );
          _events.add(RealtimeMessageUpdated(MessageItem.fromJson(payload)));
        }
        break;
      case 'message_deleted':
        if (payload != null) {
          _log(
            'received message_deleted chatId=${payload['chat_id']} id=${payload['id']}',
          );
          _events.add(RealtimeMessageDeleted(MessageItem.fromJson(payload)));
        }
        break;
      default:
        _log('ignored event type=$type');
        return;
    }
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      final socket = _socket;
      if (socket == null || socket.readyState != WebSocket.open) return;
      _log('sending ping');
      socket.add(jsonEncode({'type': 'ping', 'state': 'active'}));
    });
  }

  void _handleSocketClosed() {
    _log('socket closed');
    _closeSocket();
    _setConnected(false);
    if (AuthStore.instance.hasToken) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_reconnectTimer != null ||
        _isConnecting ||
        !AuthStore.instance.hasToken) {
      return;
    }

    final delaySeconds = _retryAttempt == 0
        ? 1
        : (_retryAttempt >= 5 ? 30 : 1 << _retryAttempt);
    _retryAttempt += 1;
    _log('schedule reconnect in ${delaySeconds}s attempt=$_retryAttempt');
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      _reconnectTimer = null;
      unawaited(_connect());
    });
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _closeSocket() {
    _log('closing socket');
    _pingTimer?.cancel();
    _pingTimer = null;
    _cancelReconnect();
    _socketSubscription?.cancel();
    _socketSubscription = null;
    _socket?.close();
    _socket = null;
  }

  void _setConnected(bool connected) {
    if (_connected == connected) return;
    _connected = connected;
    _log('connection state -> $connected');
    notifyListeners();
    _events.add(RealtimeConnectionChanged(connected));
  }
}
