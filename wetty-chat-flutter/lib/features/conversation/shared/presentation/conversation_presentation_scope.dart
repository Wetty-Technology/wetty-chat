import 'package:flutter/cupertino.dart';

/// Exposes conversation-level presentation context to the conversation subtree.
class ConversationPresentationScope extends InheritedWidget {
  const ConversationPresentationScope({
    super.key,
    required this.isThreadView,
    required super.child,
  });

  final bool isThreadView;

  static ConversationPresentationScope of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<ConversationPresentationScope>();
    assert(scope != null, 'Missing ConversationPresentationScope');
    return scope!;
  }

  static ConversationPresentationScope? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ConversationPresentationScope>();
  }

  @override
  bool updateShouldNotify(ConversationPresentationScope oldWidget) {
    return isThreadView != oldWidget.isThreadView;
  }
}
