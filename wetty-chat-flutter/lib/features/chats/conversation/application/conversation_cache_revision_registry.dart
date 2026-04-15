import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/conversation_scope.dart';

class ConversationCacheRevisionRegistry extends Notifier<int> {
  final ConversationScope arg;

  ConversationCacheRevisionRegistry(this.arg);

  @override
  int build() => 0;

  void bump() {
    state += 1;
  }
}

final conversationCacheRevisionProvider =
    NotifierProvider.family<
      ConversationCacheRevisionRegistry,
      int,
      ConversationScope
    >(ConversationCacheRevisionRegistry.new);
