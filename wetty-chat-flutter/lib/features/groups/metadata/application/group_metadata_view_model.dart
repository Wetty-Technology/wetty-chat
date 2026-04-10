import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../chats/list/data/chat_repository.dart';
import '../data/group_metadata_models.dart';
import '../data/group_metadata_repository.dart';

class GroupMetadataViewModel extends AsyncNotifier<ChatMetadata> {
  final String arg;

  GroupMetadataViewModel(this.arg);

  @override
  Future<ChatMetadata> build() async {
    final chatId = arg;
    final repository = ref.read(groupMetadataRepositoryProvider);
    return repository.fetchMetadata(chatId);
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(groupMetadataRepositoryProvider);
      return repository.fetchMetadata(arg);
    });
  }

  Future<ChatMetadata> updateMetadata({
    String? name,
    String? description,
    int? avatarImageId,
    String? visibility,
  }) async {
    final previous = state.value;
    try {
      final repository = ref.read(groupMetadataRepositoryProvider);
      final updated = await repository.updateMetadata(
        arg,
        name: name,
        description: description,
        avatarImageId: avatarImageId,
        visibility: visibility,
      );
      state = AsyncData(updated);
      ref
          .read(chatListStateProvider.notifier)
          .updateChatMetadata(
            chatId: updated.id,
            name: updated.name,
            mutedUntil: updated.mutedUntil,
          );
      return updated;
    } catch (error, stackTrace) {
      if (previous != null) {
        state = AsyncData(previous);
      } else {
        state = AsyncError(error, stackTrace);
      }
      rethrow;
    }
  }

  Future<void> muteChat({int? durationSeconds}) async {
    final repository = ref.read(groupMetadataRepositoryProvider);
    final mutedUntil = await repository.muteChat(
      arg,
      durationSeconds: durationSeconds,
    );
    // Update local ChatMetadata state
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(mutedUntil: mutedUntil));
    }
    // Sync to chat list
    ref.read(chatListStateProvider.notifier).updateChatMutedUntil(
      chatId: arg,
      mutedUntil: mutedUntil,
    );
  }

  Future<void> unmuteChat() async {
    final repository = ref.read(groupMetadataRepositoryProvider);
    await repository.unmuteChat(arg);
    // Update local ChatMetadata state
    final current = state.value;
    if (current != null) {
      state = AsyncData(current.copyWith(mutedUntil: null));
    }
    // Sync to chat list (clear mute)
    ref.read(chatListStateProvider.notifier).updateChatMutedUntil(
      chatId: arg,
      mutedUntil: null,
    );
  }
}

final groupMetadataViewModelProvider =
    AsyncNotifierProvider.family<GroupMetadataViewModel, ChatMetadata, String>(
      GroupMetadataViewModel.new,
    );
