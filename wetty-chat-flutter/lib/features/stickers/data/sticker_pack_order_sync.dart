import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/models/websocket_api_models.dart';
import '../../../core/network/websocket_service.dart';
import 'sticker_pack_order_store.dart';

/// Provider that listens to WS events and syncs pack order to local store.
/// Keep alive by watching it from the app widget or sticker feature root.
final stickerPackOrderSyncProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<ApiWsEvent>>(wsEventsProvider, (_, next) {
    final event = next.value;
    if (event is StickerPackOrderUpdatedWsEvent) {
      final order = event.payload.order
          .map(
            (dto) => StickerPackOrderItem(
              stickerPackId: dto.stickerPackId,
              lastUsedOn: dto.lastUsedOn,
            ),
          )
          .toList();
      ref.read(stickerPackOrderProvider.notifier).replaceOrderFromWs(order);
    }
  });
});
