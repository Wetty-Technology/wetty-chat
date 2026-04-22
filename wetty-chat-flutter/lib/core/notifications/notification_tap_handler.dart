import 'dart:async';
import 'dart:developer' as developer;

import 'package:go_router/go_router.dart';

import '../../app/routing/route_names.dart';
import '../../features/conversation/shared/domain/launch_request.dart';
import 'apns_channel.dart';

/// Handles push notification taps by navigating to the relevant chat or thread.
///
/// Initialize this once in the app widget via [ref.listen] or by reading the
/// provider. It subscribes to [ApnsChannel.onNotificationTapped] and uses
/// [GoRouter] to navigate.
class NotificationTapHandler {
  NotificationTapHandler(
    this._apns,
    this._router, {
    this.onNotificationHandled,
  }) {
    _sub = _apns.onNotificationTapped.listen(_handleTap);
  }

  final ApnsChannel _apns;
  final GoRouter _router;
  final Future<void> Function()? onNotificationHandled;
  StreamSubscription<Map<String, dynamic>>? _sub;

  /// Process the launch notification that cold-started the app, if any.
  Future<void> handleLaunchNotification() async {
    final payload = await _apns.getLaunchNotification();
    if (payload != null) {
      _handleTap(payload);
    }
  }

  void _handleTap(Map<String, dynamic> payload) {
    final chatId = payload['chatId'] as String?;
    if (chatId == null) {
      developer.log('Notification tap missing chatId', name: 'NotificationTap');
      return;
    }

    final threadRootId = payload['threadRootId'] as String?;
    final messageIdStr = payload['messageId'] as String?;
    final messageId = messageIdStr != null ? int.tryParse(messageIdStr) : null;
    final extra = _launchExtraForMessage(messageId);

    if (threadRootId != null && threadRootId.isNotEmpty) {
      developer.log(
        'Resetting navigation directly to thread $threadRootId in chat '
        '$chatId from notification tap',
        name: 'NotificationTap',
      );
      _router.go(AppRoutes.threadDetail(chatId, threadRootId), extra: extra);
    } else {
      developer.log(
        'Resetting navigation to chat $chatId from notification tap',
        name: 'NotificationTap',
      );
      _router.go(AppRoutes.chatDetail(chatId), extra: extra);
    }

    final refresh = onNotificationHandled;
    if (refresh != null) {
      unawaited(refresh());
    }
  }

  void dispose() {
    _sub?.cancel();
  }

  Map<String, dynamic>? _launchExtraForMessage(int? messageId) {
    if (messageId == null) {
      return null;
    }
    return <String, dynamic>{
      'launchRequest': LaunchRequest.message(messageId: messageId),
    };
  }
}
