import 'package:chahua/core/api/models/messages_api_models.dart';
import 'package:chahua/core/api/models/pins_api_models.dart';
import 'package:chahua/features/conversation/pins/data/pinned_messages_api_service.dart';
import 'package:chahua/features/conversation/pins/domain/pinned_message.dart';
import 'package:chahua/features/conversation/shared/domain/conversation_identity.dart';
import 'package:chahua/features/shared/model/message/message.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PinnedMessagesNotifier extends AsyncNotifier<List<PinnedMessage>> {
  PinnedMessagesNotifier(this._identity);

  final ConversationIdentity _identity;

  @override
  Future<List<PinnedMessage>> build() async {
    if (_identity.threadRootId != null) {
      return const <PinnedMessage>[];
    }
    final pins = await ref
        .read(pinnedMessagesApiServiceProvider)
        .listPins(_identity.chatId);
    return _sortedPins(pins);
  }

  Future<void> pinMessage(int messageId) async {
    if (_identity.threadRootId != null) {
      return;
    }
    final created = await ref
        .read(pinnedMessagesApiServiceProvider)
        .pinMessage(chatId: _identity.chatId, messageId: messageId);
    _upsert(created);
  }

  Future<void> unpin(PinnedMessage pin) async {
    if (_identity.threadRootId != null) {
      return;
    }
    await ref
        .read(pinnedMessagesApiServiceProvider)
        .unpinMessage(chatId: _identity.chatId, pinId: pin.id);
    _removePin(pin.id);
  }

  void applyPinAdded(PinUpdatePayloadDto payload) {
    if (!_matchesPayload(payload.chatId)) {
      return;
    }
    final pin = payload.pin?.toDomain();
    if (pin == null) {
      ref.invalidateSelf();
      return;
    }
    _upsert(pin);
  }

  void applyPinRemoved(PinUpdatePayloadDto payload) {
    if (!_matchesPayload(payload.chatId)) {
      return;
    }
    _removePin(payload.pinId);
  }

  void patchMessage(MessageItemDto dto) {
    if (!_matchesPayload(dto.chatId)) {
      return;
    }
    final currentPins = state.value;
    if (currentPins == null) {
      return;
    }
    final nextMessage = ConversationMessageV2.fromMessageItemDto(dto);
    final nextPins = currentPins
        .map((pin) {
          if (pin.messageId != dto.id) {
            return pin;
          }
          return pin.copyWith(message: nextMessage);
        })
        .toList(growable: false);
    state = AsyncData(_sortedPins(nextPins));
  }

  bool _matchesPayload(int chatId) {
    return _identity.threadRootId == null && _identity.chatId == chatId;
  }

  void _upsert(PinnedMessage pin) {
    final currentPins = state.value ?? const <PinnedMessage>[];
    final withoutExisting = currentPins
        .where((item) => item.id != pin.id && item.messageId != pin.messageId)
        .toList(growable: false);
    state = AsyncData(_sortedPins(<PinnedMessage>[pin, ...withoutExisting]));
  }

  void _removePin(int pinId) {
    final currentPins = state.value ?? const <PinnedMessage>[];
    state = AsyncData(
      _sortedPins(
        currentPins.where((pin) => pin.id != pinId).toList(growable: false),
      ),
    );
  }
}

List<PinnedMessage> _sortedPins(List<PinnedMessage> pins) {
  final sorted = pins.toList(growable: false);
  sorted.sort((a, b) {
    final aMessageId = a.messageId;
    final bMessageId = b.messageId;
    if (aMessageId != null && bMessageId != null) {
      final byMessage = bMessageId.compareTo(aMessageId);
      if (byMessage != 0) {
        return byMessage;
      }
    }
    return b.pinnedAt.compareTo(a.pinnedAt);
  });
  return sorted;
}

final pinnedMessagesProvider =
    AsyncNotifierProvider.family<
      PinnedMessagesNotifier,
      List<PinnedMessage>,
      ConversationIdentity
    >(PinnedMessagesNotifier.new);
