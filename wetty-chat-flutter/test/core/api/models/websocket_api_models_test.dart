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

    test('ApiWsEvent parses pinAdded payloads', () {
      final event =
          ApiWsEvent.fromJson(<String, Object?>{
                'type': 'pinAdded',
                'payload': <String, Object?>{
                  'chatId': '10',
                  'pinId': '100',
                  'messageId': '200',
                  'pin': <String, Object?>{
                    'id': '100',
                    'chatId': '10',
                    'message': <String, Object?>{
                      'id': '200',
                      'chatId': '10',
                      'message': 'Pinned hello',
                      'sender': <String, Object?>{'uid': 2, 'name': 'Ada'},
                    },
                    'pinnedBy': 2,
                    'pinnedAt': '2026-04-26T10:15:00Z',
                  },
                },
              })
              as PinAddedWsEvent?;

      expect(event, isNotNull);
      expect(event!.payload.chatId, 10);
      expect(event.payload.pinId, 100);
      expect(event.payload.messageId, 200);
      expect(event.payload.pin?.message.message, 'Pinned hello');
    });

    test('ApiWsEvent parses pinRemoved payloads', () {
      final event =
          ApiWsEvent.fromJson(<String, Object?>{
                'type': 'pinRemoved',
                'payload': <String, Object?>{
                  'chatId': '10',
                  'pinId': '100',
                  'messageId': '200',
                },
              })
              as PinRemovedWsEvent?;

      expect(event, isNotNull);
      expect(event!.payload.chatId, 10);
      expect(event.payload.pinId, 100);
      expect(event.payload.messageId, 200);
      expect(event.payload.pin, isNull);
    });

    test('ApiWsEvent parses threadMembershipChanged payloads', () {
      final event =
          ApiWsEvent.fromJson(<String, Object?>{
                'type': 'threadMembershipChanged',
                'payload': <String, Object?>{
                  'chatId': '10',
                  'threadRootId': '200',
                },
              })
              as ThreadMembershipChangedWsEvent?;

      expect(event, isNotNull);
      expect(event!.payload.chatId, 10);
      expect(event.payload.threadRootId, 200);
    });
  });
}
