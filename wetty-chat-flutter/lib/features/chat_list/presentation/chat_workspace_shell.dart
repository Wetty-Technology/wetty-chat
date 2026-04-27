import 'package:chahua/app/routing/route_names.dart';
import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/features/chat_list/presentation/chat_list_v2_page.dart';
import 'package:chahua/features/chat_list/presentation/chat_workspace_layout_scope.dart';
import 'package:chahua/l10n/app_localizations.dart';
import 'package:flutter/cupertino.dart';

class ChatWorkspaceShell extends StatelessWidget {
  const ChatWorkspaceShell({
    super.key,
    required this.location,
    required this.child,
  });

  static const double desktopBreakpoint = 900;
  static const double listPaneWidth = 360;

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < desktopBreakpoint) {
          return ChatWorkspaceLayoutScope(isSplit: false, child: child);
        }

        return ChatWorkspaceLayoutScope(
          isSplit: true,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ColoredBox(
                color: context.appColors.backgroundPrimary,
                child: SizedBox(
                  width: listPaneWidth,
                  child: ChatListV2Page(
                    embedded: true,
                    selectedChatId: _selectedChatId(location),
                    selectedThreadRootId: _selectedThreadRootId(location),
                  ),
                ),
              ),
              SizedBox(
                width: 1,
                child: ColoredBox(color: context.appColors.separator),
              ),
              Expanded(
                child: _isChatsRoot(location)
                    ? const _EmptyDetailPane()
                    : DecoratedBox(
                        decoration: BoxDecoration(
                          color: context.appColors.backgroundPrimary,
                        ),
                        child: child,
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  static bool _isChatsRoot(String location) {
    final uri = Uri.parse(location);
    return uri.path == AppRoutes.chats;
  }

  static String? _selectedChatId(String location) {
    final segments = Uri.parse(location).pathSegments;
    if (segments.length >= 2 && segments.first == 'chat') {
      return segments[1];
    }
    if (segments.length >= 3 && segments.first == 'thread') {
      return segments[1];
    }
    return null;
  }

  static int? _selectedThreadRootId(String location) {
    final segments = Uri.parse(location).pathSegments;
    if (segments.length >= 4 &&
        segments.first == 'chat' &&
        segments[2] == 'thread') {
      return int.tryParse(segments[3]);
    }
    if (segments.length >= 3 && segments.first == 'thread') {
      return int.tryParse(segments[2]);
    }
    return null;
  }
}

class _EmptyDetailPane extends StatelessWidget {
  const _EmptyDetailPane();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context)!;

    return DecoratedBox(
      decoration: BoxDecoration(color: colors.backgroundPrimary),
      child: Center(
        child: Text(
          l10n.selectChatPlaceholder,
          style: TextStyle(color: colors.textSecondary, fontSize: 16),
        ),
      ),
    );
  }
}
