import 'dart:async';

import '../../../../core/api/models/websocket_api_models.dart';
import '../../../../core/network/websocket_service.dart';
import '../data/message_repository.dart';

class MessageRealtimeController {
  MessageRealtimeController(this._repository);

  final MessageRepository _repository;
  StreamSubscription<ApiWsEvent>? _subscription;

  void start() {
    _subscription ??= WebSocketService.instance.events.listen(
      _repository.applyRealtimeEvent,
    );
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
