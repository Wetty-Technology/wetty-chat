import 'package:flutter/widgets.dart';

import '../api/models/websocket_api_models.dart';

WsClientAppState mapLifecycleToWsAppState(AppLifecycleState state) {
  return switch (state) {
    AppLifecycleState.resumed => WsClientAppState.active,
    AppLifecycleState.inactive ||
    AppLifecycleState.hidden ||
    AppLifecycleState.paused ||
    AppLifecycleState.detached => WsClientAppState.inactive,
  };
}
