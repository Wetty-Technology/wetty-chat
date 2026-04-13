import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/session/dev_session_store.dart';
import '../../features/auth/presentation/auth_login_view.dart';
import '../../features/auth/presentation/auth_bootstrap_view.dart';
import '../../features/chats/conversation/presentation/attachment_viewer_page.dart';
import '../../features/chats/conversation/presentation/attachment_viewer_request.dart';
import '../../features/chats/conversation/presentation/chat_detail_view.dart';
import '../../features/chats/conversation/presentation/thread_detail_view.dart';
import '../../features/chats/conversation/domain/launch_request.dart';
import '../../features/chats/list/presentation/chat_list_view.dart';
import '../../features/chats/list/presentation/new_chat_view.dart';
import '../../features/groups/members/presentation/group_members_view.dart';
import '../../features/groups/settings/presentation/group_settings_view.dart';
import '../../features/settings/presentation/dev_session_settings_view.dart';
import '../../features/settings/presentation/font_size_settings_view.dart';
import '../../features/settings/presentation/language_settings_view.dart';
import '../../features/settings/presentation/cache_settings_view.dart';
import '../../features/settings/presentation/notification_settings_view.dart';
import '../../features/settings/presentation/profile_settings_view.dart';
import '../../features/settings/presentation/settings_view.dart';
import '../../features/stickers/presentation/sticker_pack_detail_page.dart';
import '../../features/stickers/presentation/sticker_pack_list_page.dart';
import '../presentation/home_root_view.dart';
import 'route_names.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final sessionNotifier = ValueNotifier(ref.read(authSessionProvider));
  ref.listen<AuthSessionState>(authSessionProvider, (_, next) {
    sessionNotifier.value = next;
  });
  ref.onDispose(() => sessionNotifier.dispose());

  return GoRouter(
    initialLocation: AppRoutes.bootstrap,
    refreshListenable: sessionNotifier,
    redirect: (context, state) {
      final session = ref.read(authSessionProvider);
      final location = state.matchedLocation;
      final isBootstrap = location == AppRoutes.bootstrap;
      final isLogin = location == AppRoutes.login;

      if (session.isBootstrapping) {
        return isBootstrap ? null : AppRoutes.bootstrap;
      }
      if (!session.isAuthenticated) {
        return isLogin ? null : AppRoutes.login;
      }
      if (isBootstrap || isLogin) {
        return AppRoutes.chats;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.bootstrap,
        pageBuilder: (context, state) =>
            CupertinoPage(key: state.pageKey, child: const AuthBootstrapPage()),
      ),
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) =>
            CupertinoPage(key: state.pageKey, child: const AuthLoginPage()),
      ),
      // Full-screen routes outside the shell (no bottom nav, swipe-back enabled).
      GoRoute(
        path: '/attachment-viewer',
        pageBuilder: (context, state) {
          final request = state.extra! as AttachmentViewerRequest;
          return CustomTransitionPage<void>(
            key: state.pageKey,
            transitionDuration: const Duration(milliseconds: 200),
            reverseTransitionDuration: const Duration(milliseconds: 180),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            child: AttachmentViewerPage(request: request),
          );
        },
      ),
      GoRoute(
        path: '/chats/new',
        pageBuilder: (context, state) =>
            CupertinoPage(key: state.pageKey, child: const NewChatPage()),
      ),
      GoRoute(
        path: '${AppRoutes.stickerPackDetailRoot}/:packId',
        pageBuilder: (context, state) {
          final packId = state.pathParameters['packId']!;
          return CupertinoPage(
            key: state.pageKey,
            child: StickerPackDetailPage(packId: packId),
          );
        },
      ),
      GoRoute(
        path: '/chats/:chatId',
        pageBuilder: (context, state) {
          final chatId = state.pathParameters['chatId']!;
          final extra = state.extra as Map<String, dynamic>?;
          return CupertinoPage(
            key: state.pageKey,
            child: ChatDetailPage(
              chatId: chatId,
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
              return CupertinoPage(
                key: state.pageKey,
                child: GroupMembersPage(chatId: chatId),
              );
            },
          ),
          GoRoute(
            path: 'settings',
            pageBuilder: (context, state) {
              final chatId = state.pathParameters['chatId']!;
              return CupertinoPage(
                key: state.pageKey,
                child: GroupSettingsPage(chatId: chatId),
              );
            },
          ),
          GoRoute(
            path: 'thread/:threadId',
            pageBuilder: (context, state) {
              final chatId = state.pathParameters['chatId']!;
              final threadId = state.pathParameters['threadId']!;
              final extra = state.extra as Map<String, dynamic>?;
              return CupertinoPage(
                key: state.pageKey,
                child: ThreadDetailPage(
                  chatId: chatId,
                  threadRootId: threadId,
                  launchRequest:
                      extra?['launchRequest'] as LaunchRequest? ??
                      const LaunchRequest.latest(),
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
                    CupertinoPage(key: state.pageKey, child: const ChatPage()),
              ),
            ],
          ),

          // ── Branch 1: Settings ──
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                pageBuilder: (context, state) => CupertinoPage(
                  key: state.pageKey,
                  child: const SettingsPage(),
                ),
                routes: [
                  GoRoute(
                    path: 'language',
                    pageBuilder: (context, state) => CupertinoPage(
                      key: state.pageKey,
                      child: const LanguageSettingsPage(),
                    ),
                  ),
                  GoRoute(
                    path: 'font-size',
                    pageBuilder: (context, state) => CupertinoPage(
                      key: state.pageKey,
                      child: const FontSizeSettingsPage(),
                    ),
                  ),
                  GoRoute(
                    path: 'profile',
                    pageBuilder: (context, state) => CupertinoPage(
                      key: state.pageKey,
                      child: const ProfileSettingsPage(),
                    ),
                  ),
                  GoRoute(
                    path: 'dev-session',
                    pageBuilder: (context, state) => CupertinoPage(
                      key: state.pageKey,
                      child: const DevSessionSettingsPage(),
                    ),
                  ),
                  GoRoute(
                    path: 'notifications',
                    pageBuilder: (context, state) => CupertinoPage(
                      key: state.pageKey,
                      child: const NotificationSettingsPage(),
                    ),
                  ),
                  GoRoute(
                    path: 'cache',
                    pageBuilder: (context, state) => CupertinoPage(
                      key: state.pageKey,
                      child: const CacheSettingsPage(),
                    ),
                  ),
                  GoRoute(
                    path: 'sticker-packs',
                    pageBuilder: (context, state) => CupertinoPage(
                      key: state.pageKey,
                      child: const StickerPackListPage(),
                    ),
                    routes: [
                      GoRoute(
                        path: ':packId',
                        pageBuilder: (context, state) {
                          final packId = state.pathParameters['packId']!;
                          return CupertinoPage(
                            key: state.pageKey,
                            child: StickerPackDetailPage(packId: packId),
                          );
                        },
                      ),
                    ],
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
