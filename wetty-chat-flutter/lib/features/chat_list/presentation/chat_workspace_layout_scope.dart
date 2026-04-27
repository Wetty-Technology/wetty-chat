import 'package:flutter/widgets.dart';

class ChatWorkspaceLayoutScope extends InheritedWidget {
  const ChatWorkspaceLayoutScope({
    super.key,
    required this.isSplit,
    required super.child,
  });

  final bool isSplit;

  static bool isSplitLayout(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<ChatWorkspaceLayoutScope>()
            ?.isSplit ??
        false;
  }

  @override
  bool updateShouldNotify(ChatWorkspaceLayoutScope oldWidget) {
    return isSplit != oldWidget.isSplit;
  }
}
