import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session/dev_session_store.dart';
import '../../features/chats/detail/presentation/attachment_viewer_page.dart';
import '../../features/chats/detail/presentation/chat_detail_view.dart';
import '../../features/chats/detail/domain/launch_request.dart';
import '../../features/chats/list/presentation/chat_list_view.dart';
import '../../features/chats/list/presentation/new_chat_view.dart';
import '../../features/chats/models/message_models.dart';
import '../../features/groups/members/presentation/group_members_view.dart';
import '../../features/groups/settings/presentation/group_settings_view.dart';
import '../../features/settings/presentation/dev_session_settings_view.dart';
import '../../features/settings/presentation/font_size_settings_view.dart';
import '../../features/settings/presentation/language_settings_view.dart';
import '../../features/settings/presentation/notification_settings_view.dart';
import '../../features/settings/presentation/profile_settings_view.dart';
import '../../features/settings/presentation/settings_view.dart';
import '../presentation/home_root_view.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  // Bridge devSessionProvider to a ValueNotifier for GoRouter's refreshListenable.
  final sessionNotifier = ValueNotifier(ref.read(devSessionProvider));
  ref.listen<int>(devSessionProvider, (_, next) {
    sessionNotifier.value = next;
  });
  ref.onDispose(() => sessionNotifier.dispose());

  return GoRouter(
    initialLocation: '/chats',
    refreshListenable: sessionNotifier,
    routes: [
      // Full-screen routes outside the shell (no bottom nav, swipe-back enabled).
      GoRoute(
        path: '/attachment-viewer',
        pageBuilder: (context, state) {
          final attachment = state.extra! as AttachmentItem;
          return CupertinoPage(
            child: AttachmentViewerPage(attachment: attachment),
          );
        },
      ),
      GoRoute(
        path: '/chats/new',
        pageBuilder: (context, state) =>
            const CupertinoPage(child: NewChatPage()),
      ),
      GoRoute(
        path: '/chats/:chatId',
        pageBuilder: (context, state) {
          final chatId = state.pathParameters['chatId']!;
          final extra = state.extra as Map<String, dynamic>?;
          return CupertinoPage(
            child: ChatDetailPage(
              chatId: chatId,
              chatName: extra?['chatName'] as String? ?? 'Chat $chatId',
              launchRequest:
                  extra?['launchRequest'] as LaunchRequest? ??
                  const LaunchRequest.latest(),
            ),
          );
        },
        routes: [
          GoRoute(
            path: 'members',
            pageBuilder: (context, state) {
              final chatId = state.pathParameters['chatId']!;
              return CupertinoPage(child: GroupMembersPage(chatId: chatId));
            },
          ),
          GoRoute(
            path: 'settings',
            pageBuilder: (context, state) {
              final chatId = state.pathParameters['chatId']!;
              final extra = state.extra as Map<String, dynamic>?;
              final currentName = extra?['currentName'] as String? ?? '';
              return CupertinoPage(
                child: GroupSettingsPage(
                  chatId: chatId,
                  currentName: currentName,
                ),
              );
            },
          ),
        ],
      ),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          // ── Branch 0: Chats ──
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/chats',
                pageBuilder: (context, state) =>
                    const CupertinoPage(child: ChatPage()),
              ),
            ],
          ),

          // ── Branch 1: Settings ──
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                pageBuilder: (context, state) =>
                    const CupertinoPage(child: SettingsPage()),
                routes: [
                  GoRoute(
                    path: 'language',
                    pageBuilder: (context, state) =>
                        const CupertinoPage(child: LanguageSettingsPage()),
                  ),
                  GoRoute(
                    path: 'font-size',
                    pageBuilder: (context, state) =>
                        const CupertinoPage(child: FontSizeSettingsPage()),
                  ),
                  GoRoute(
                    path: 'profile',
                    pageBuilder: (context, state) =>
                        const CupertinoPage(child: ProfileSettingsPage()),
                  ),
                  GoRoute(
                    path: 'dev-session',
                    pageBuilder: (context, state) =>
                        const CupertinoPage(child: DevSessionSettingsPage()),
                  ),
                  GoRoute(
                    path: 'notifications',
                    pageBuilder: (context, state) =>
                        const CupertinoPage(child: NotificationSettingsPage()),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
