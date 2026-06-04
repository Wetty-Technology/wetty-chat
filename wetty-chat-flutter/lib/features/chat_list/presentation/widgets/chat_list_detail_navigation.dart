import 'package:chahua/features/chat_list/application/chat_list_v2_scope.dart';
import 'package:chahua/features/chat_list/presentation/chat_workspace_layout_scope.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

void openChatListDetail({
  required BuildContext context,
  required ChatListV2Scope scope,
  required String route,
  Object? extra,
}) {
  final isSplit = ChatWorkspaceLayoutScope.isSplitLayout(context);
  if (!isSplit) {
    context.push(route, extra: extra);
    return;
  }
  context.go(route, extra: extra);
}
