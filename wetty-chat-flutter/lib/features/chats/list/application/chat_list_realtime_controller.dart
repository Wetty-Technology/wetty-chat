import 'dart:async';

import '../../../../core/api/models/websocket_api_models.dart';
import '../../../../core/network/websocket_service.dart';
import '../data/chat_repository.dart';

class ChatListRealtimeController {
  ChatListRealtimeController(this._repository);

  final ChatRepository _repository;
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
