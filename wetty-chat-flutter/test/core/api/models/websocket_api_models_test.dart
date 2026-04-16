import 'package:flutter_test/flutter_test.dart';

import 'package:chahua/core/api/models/websocket_api_models.dart';

void main() {
  group('websocket dto serialization', () {
    test('WsPingMessageDto serializes stateful ping payloads', () {
      const dto = WsPingMessageDto(state: WsClientAppState.inactive);

      expect(dto.toJson(), {'type': 'ping', 'state': 'inactive'});
    });

    test('WsAppStateMessageDto serializes app state updates', () {
      const dto = WsAppStateMessageDto(state: WsClientAppState.active);

      expect(dto.toJson(), {'type': 'appState', 'state': 'active'});
    });
  });
}
