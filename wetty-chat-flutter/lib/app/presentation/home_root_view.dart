import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:chahua/l10n/app_localizations.dart';

import '../routing/route_names.dart';
import '../../core/notifications/unread_badge_provider.dart';
import '../../features/shared/application/app_refresh_coordinator.dart';
import '../theme/style_config.dart';

/// Shell widget for the [StatefulShellRoute.indexedStack].
/// Renders the active branch content with a custom bottom navigation bar.
class HomeShell extends ConsumerWidget {
  const HomeShell({
    super.key,
    required this.navigationShell,
    required this.location,
  });

  final StatefulNavigationShell navigationShell;
  final String location;

  static const double _splitLayoutBreakpoint = 900;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.appColors;
    final l10n = AppLocalizations.of(context)!;
    final unreadState = ref.watch(unreadBadgeProvider);
    final tabs = [
      _HomeTabData(
        icon: CupertinoIcons.chat_bubble_2_fill,
        label: l10n.tabChats,
        badgeCount: unreadState.combinedUnreadTotal,
      ),
      _HomeTabData(icon: CupertinoIcons.gear_alt_fill, label: l10n.tabSettings),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final showBottomNav =
            constraints.maxWidth < _splitLayoutBreakpoint &&
            !_isCompactChatDetailRoute;

        return DecoratedBox(
          decoration: BoxDecoration(color: colors.backgroundPrimary),
          child: Column(
            children: [
              Expanded(child: navigationShell),
              if (showBottomNav)
                _BottomNavBar(
                  items: tabs,
                  selectedIndex: navigationShell.currentIndex,
                  onTap: (index) {
                    if (index == 0) {
                      // TODO: Revisit whether tab-tap reconcile is needed once v2
                      // read-state sync points are fully defined.
                      unawaited(
                        ref
                            .read(appRefreshCoordinatorProvider)
                            .recover(AppRefreshReason.tabReselected),
                      );
                    }
                    navigationShell.goBranch(
                      index,
                      initialLocation: index == navigationShell.currentIndex,
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  bool get _isCompactChatDetailRoute {
    if (navigationShell.currentIndex != 0) {
      return false;
    }
    final path = Uri.parse(location).path;
    return path != AppRoutes.chats;
  }
}

class _BottomNavBar extends StatelessWidget {
  const _BottomNavBar({
    required this.items,
    required this.selectedIndex,
    required this.onTap,
  });

  final List<_HomeTabData> items;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.backgroundSecondary,
        border: Border(top: BorderSide(color: colors.separator, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 49,
          child: Row(
            children: [
              for (var index = 0; index < items.length; index++)
                Expanded(
                  child: _BottomNavItem(
                    data: items[index],
                    isSelected: index == selectedIndex,
                    onTap: () => onTap(index),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.data,
    required this.isSelected,
    required this.onTap,
  });

  final _HomeTabData data;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = context.appColors.accentPrimary;
    final inactiveColor = context.appColors.inactive;
    final color = isSelected ? activeColor : inactiveColor;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(data.icon, size: 24, color: color),
                  if (data.badgeCount > 0)
                    Positioned(
                      top: -4,
                      right: -10,
                      child: _TabBadge(count: data.badgeCount),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                data.label,
                style: appCaptionTextStyle(
                  context,
                  color: color,
                  fontWeight: AppFontWeights.medium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeTabData {
  const _HomeTabData({
    required this.icon,
    required this.label,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final int badgeCount;
}

class _TabBadge extends StatelessWidget {
  const _TabBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final text = count > 99 ? '99+' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: context.appColors.unreadBadge,
        borderRadius: BorderRadius.circular(8),
      ),
      constraints: const BoxConstraints(minWidth: 16),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: appOnDarkTextStyle(
          context,
          color: context.appColors.unreadBadgeText,
          fontSize: AppFontSizes.unreadBadge,
          fontWeight: AppFontWeights.semibold,
        ),
      ),
    );
  }
}
