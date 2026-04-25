import 'package:chahua/features/chat_list/presentation/chat_list_v2_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chahua/app/presentation/home_root_view.dart';
import 'package:chahua/app/routing/route_names.dart';
import 'package:chahua/core/session/dev_session_store.dart';
import 'package:chahua/features/auth/presentation/auth_bootstrap_view.dart';
import 'package:chahua/features/auth/presentation/auth_login_view.dart';
import 'package:chahua/features/conversation/shared/domain/launch_request.dart';
import 'package:chahua/features/conversation/media/presentation/attachment_viewer_page.dart';
import 'package:chahua/features/conversation/media/presentation/attachment_viewer_request.dart';
import 'package:chahua/features/conversation/shared/presentation/chat_detail_v2_view.dart';
import 'package:chahua/features/conversation/shared/presentation/thread_detail_v2_view.dart';
import 'package:chahua/features/groups/members/presentation/group_members_view.dart';
import 'package:chahua/features/groups/settings/presentation/group_settings_view.dart';
import 'package:chahua/features/settings/presentation/cache_settings_view.dart';
import 'package:chahua/features/settings/presentation/dev_session_settings_view.dart';
import 'package:chahua/features/settings/presentation/font_size_settings_view.dart';
import 'package:chahua/features/settings/presentation/language_settings_view.dart';
import 'package:chahua/features/settings/presentation/notification_settings_view.dart';
import 'package:chahua/features/settings/presentation/profile_settings_view.dart';
import 'package:chahua/features/settings/presentation/settings_view.dart';
import 'package:chahua/features/stickers/presentation/sticker_pack_detail_page.dart';
import 'package:chahua/features/stickers/presentation/sticker_pack_list_page.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(
  debugLabel: 'root',
);
final GlobalKey<NavigatorState> _chatsBranchNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'chats-branch');
final GlobalKey<NavigatorState> _settingsBranchNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'settings-branch');

final appRouterProvider = Provider<GoRouter>((ref) {
  final sessionNotifier = ValueNotifier(ref.read(authSessionProvider));
  ref.listen<AuthSessionState>(authSessionProvider, (_, next) {
    sessionNotifier.value = next;
  });
  ref.onDispose(() => sessionNotifier.dispose());

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
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
        path: '${AppRoutes.stickerPackDetailRoot}/:packId',
        pageBuilder: (context, state) {
          final packId = state.pathParameters['packId']!;
          return CupertinoPage(
            key: state.pageKey,
            child: StickerPackDetailPage(packId: packId),
          );
        },
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          // ── Branch 0: Chats ──
          StatefulShellBranch(
            navigatorKey: _chatsBranchNavigatorKey,
            routes: [
              GoRoute(
                path: AppRoutes.chats,
                pageBuilder: (context, state) => CupertinoPage(
                  key: state.pageKey,
                  child: const ChatListV2Page(),
                ),
                routes: [
                  GoRoute(
                    parentNavigatorKey: _rootNavigatorKey,
                    path: 'chat/:chatId',
                    pageBuilder: (context, state) {
                      final chatId = int.parse(state.pathParameters['chatId']!);
                      final extra = state.extra as Map<String, dynamic>?;
                      return CupertinoPage(
                        key: state.pageKey,
                        child: ChatDetailV2Page(
                          chatId: chatId,
                          launchRequest:
                              extra?['launchRequest'] as LaunchRequest? ??
                              const LaunchRequest.latest(),
                        ),
                      );
                    },
                    routes: [
                      GoRoute(
                        parentNavigatorKey: _rootNavigatorKey,
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
                        parentNavigatorKey: _rootNavigatorKey,
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
                        parentNavigatorKey: _rootNavigatorKey,
                        path: 'thread/:threadId/new',
                        pageBuilder: (context, state) {
                          final chatId = int.parse(
                            state.pathParameters['chatId']!,
                          );
                          final threadId = int.parse(
                            state.pathParameters['threadId']!,
                          );
                          final extra = state.extra as Map<String, dynamic>?;
                          return CupertinoPage(
                            key: state.pageKey,
                            child: ThreadDetailV2Page(
                              chatId: chatId,
                              threadRootId: threadId,
                              launchRequest:
                                  extra?['launchRequest'] as LaunchRequest? ??
                                  const LaunchRequest.latest(),
                              isNewThread: true,
                            ),
                          );
                        },
                      ),
                      GoRoute(
                        parentNavigatorKey: _rootNavigatorKey,
                        path: 'thread/:threadId',
                        pageBuilder: (context, state) {
                          final chatId = int.parse(
                            state.pathParameters['chatId']!,
                          );
                          final threadId = int.parse(
                            state.pathParameters['threadId']!,
                          );
                          final extra = state.extra as Map<String, dynamic>?;
                          return CupertinoPage(
                            key: state.pageKey,
                            child: ThreadDetailV2Page(
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
                  GoRoute(
                    parentNavigatorKey: _rootNavigatorKey,
                    path: 'thread/:chatId/:threadId',
                    pageBuilder: (context, state) {
                      final chatId = int.parse(state.pathParameters['chatId']!);
                      final threadId = int.parse(
                        state.pathParameters['threadId']!,
                      );
                      final extra = state.extra as Map<String, dynamic>?;
                      return CupertinoPage(
                        key: state.pageKey,
                        child: ThreadDetailV2Page(
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
            ],
          ),

          // ── Branch 1: Settings ──
          StatefulShellBranch(
            navigatorKey: _settingsBranchNavigatorKey,
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
