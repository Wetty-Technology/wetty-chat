import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/core/notifications/push_notification_provider.dart';
import 'package:chahua/l10n/app_localizations.dart';

class NotificationSettingsPage extends ConsumerWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final pushState = ref.watch(pushNotificationProvider);

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.settingsNotifications),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            CupertinoListSection.insetGrouped(
              header: const Text('PUSH NOTIFICATIONS'),
              children: [_buildPermissionTile(context, ref, pushState)],
            ),
            if (pushState.isAuthorized)
              CupertinoListSection.insetGrouped(
                header: const Text('STATUS'),
                children: [
                  CupertinoListTile(
                    title: const Text('Server Registration'),
                    trailing: pushState.isLoading
                        ? const CupertinoActivityIndicator()
                        : Icon(
                            pushState.isSubscribed
                                ? CupertinoIcons.checkmark_circle_fill
                                : CupertinoIcons.xmark_circle,
                            color: pushState.isSubscribed
                                ? CupertinoColors.activeGreen
                                : CupertinoColors.systemRed,
                          ),
                  ),
                  if (pushState.environment != null)
                    CupertinoListTile(
                      title: const Text('Environment'),
                      additionalInfo: Text(pushState.environment!),
                    ),
                  if (pushState.deviceToken != null)
                    CupertinoListTile(
                      title: const Text('Device Token'),
                      additionalInfo: Text(
                        '${pushState.deviceToken!.substring(0, 8)}...',
                      ),
                    ),
                ],
              ),
            if (pushState.lastError != null)
              CupertinoListSection.insetGrouped(
                header: const Text('ERROR'),
                children: [
                  CupertinoListTile(
                    title: Text(
                      pushState.lastError!,
                      style: appMetaTextStyle(
                        context,
                        color: CupertinoColors.destructiveRed,
                      ),
                    ),
                  ),
                ],
              ),
            if (pushState.isAuthorized &&
                !pushState.isSubscribed &&
                !pushState.isLoading)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: CupertinoButton.filled(
                  onPressed: () {
                    ref
                        .read(pushNotificationProvider.notifier)
                        .retrySubscription();
                  },
                  child: const Text('Retry Registration'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionTile(
    BuildContext context,
    WidgetRef ref,
    PushNotificationState pushState,
  ) {
    if (pushState.isUnsupported) {
      return const CupertinoListTile(
        title: Text('Notifications Unavailable'),
        subtitle: Text('Push notifications are not supported on this platform'),
      );
    }
    if (pushState.isAuthorized) {
      return const CupertinoListTile(
        title: Text('Notifications Enabled'),
        trailing: Icon(
          CupertinoIcons.checkmark_circle_fill,
          color: CupertinoColors.activeGreen,
        ),
      );
    }
    if (pushState.isDenied) {
      return CupertinoListTile(
        title: const Text('Notifications Disabled'),
        subtitle: const Text('Tap to open Settings and enable notifications'),
        trailing: const CupertinoListTileChevron(),
        onTap: () => launchUrl(Uri.parse('app-settings:')),
      );
    }
    // notDetermined or unknown — show enable button.
    return CupertinoListTile(
      title: const Text('Enable Notifications'),
      trailing: pushState.isLoading
          ? const CupertinoActivityIndicator()
          : const CupertinoListTileChevron(),
      onTap: pushState.isLoading
          ? null
          : () {
              ref
                  .read(pushNotificationProvider.notifier)
                  .requestPermissionAndRegister();
            },
    );
  }
}
