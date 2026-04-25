import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../core/network/api_config.dart';
import '../core/network/ws_app_visibility.dart';
import '../core/network/ws_event_router.dart';
import '../core/network/websocket_service.dart';
import '../core/notifications/apns_channel.dart';
import '../core/notifications/notification_tap_handler.dart';
import '../core/notifications/push_notification_provider.dart';
import '../core/notifications/unread_badge_provider.dart';
import '../core/session/dev_session_store.dart';
import '../core/settings/app_settings_store.dart';
import '../features/shared/application/app_refresh_coordinator.dart';
import 'routing/app_router.dart';
import 'theme/style_config.dart';

class WettyChatApp extends ConsumerStatefulWidget {
  const WettyChatApp({super.key});

  @override
  ConsumerState<WettyChatApp> createState() => _WettyChatAppState();
}

class _WettyChatAppState extends ConsumerState<WettyChatApp>
    with WidgetsBindingObserver {
  NotificationTapHandler? _tapHandler;
  bool _pushInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tapHandler?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(webSocketProvider).updateAppState(mapLifecycleToWsAppState(state));
    if (state == AppLifecycleState.resumed) {
      // Retry push subscription if a previous attempt failed.
      ref.read(pushNotificationProvider.notifier).ensureSubscribed();
      unawaited(
        ref
            .read(appRefreshCoordinatorProvider)
            .recover(AppRefreshReason.appResumed),
      );
    }
  }

  void _initPushIfNeeded() {
    if (_pushInitialized) return;
    _pushInitialized = true;

    final apns = ref.read(apnsChannelProvider);
    final router = ref.read(appRouterProvider);
    _tapHandler = NotificationTapHandler(
      apns,
      router,
      onNotificationHandled: () => ref
          .read(appRefreshCoordinatorProvider)
          .recover(AppRefreshReason.notificationHandled),
    );
    _tapHandler!.handleLaunchNotification();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final locale = settings.language.toLocale();
    final router = ref.watch(appRouterProvider);
    final session = ref.watch(authSessionProvider);
    ref.watch(unreadBadgeProvider);
    ref.watch(wsEventRouterProvider);

    // Keep ApiSession bridge in sync for deep presentation-layer code.
    ApiSession.updateSession(
      userId: session.currentUserId,
      authHeaders: session.authHeaders,
    );

    // Initialize push notification handling once the router is available.
    _initPushIfNeeded();

    // React to auth state changes for push subscription management.
    ref.listen<AuthSessionState>(authSessionProvider, (prev, next) {
      if (next.isAuthenticated && prev?.isAuthenticated != true) {
        // User just logged in — ensure push subscription is active.
        ref.read(pushNotificationProvider.notifier).ensureSubscribed();
      } else if (!next.isAuthenticated && prev?.isAuthenticated == true) {
        // User logged out — unsubscribe from push.
        ref.read(pushNotificationProvider.notifier).unsubscribe();
      }
    });

    return CupertinoApp.router(
      theme: appCupertinoTheme,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
  }
}
