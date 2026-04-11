import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'thread_api_service.dart';

typedef ThreadSubscriptionArgs = ({String chatId, int threadRootId});

class ThreadSubscriptionNotifier extends AsyncNotifier<bool> {
  final ThreadSubscriptionArgs arg;

  ThreadSubscriptionNotifier(this.arg);

  @override
  Future<bool> build() async {
    return ref
        .read(threadApiServiceProvider)
        .getThreadSubscriptionStatus(arg.chatId, arg.threadRootId);
  }

  Future<void> toggle() async {
    final current = state.value ?? false;
    final api = ref.read(threadApiServiceProvider);
    final arg = this.arg;

    // Optimistic update
    state = AsyncData(!current);
    try {
      if (current) {
        await api.unsubscribeFromThread(arg.chatId, arg.threadRootId);
      } else {
        await api.subscribeToThread(arg.chatId, arg.threadRootId);
      }
    } catch (e) {
      // Revert on failure
      state = AsyncData(current);
      rethrow;
    }
  }
}

final threadSubscriptionProvider =
    AsyncNotifierProvider.family<
      ThreadSubscriptionNotifier,
      bool,
      ThreadSubscriptionArgs
    >(ThreadSubscriptionNotifier.new, isAutoDispose: true);
