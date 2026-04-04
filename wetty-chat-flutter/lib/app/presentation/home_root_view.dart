import 'package:flutter/cupertino.dart';

import '../theme/style_config.dart';
import '../../features/chats/chats.dart';
import '../../features/settings/settings.dart';

class HomeRootPage extends StatefulWidget {
  const HomeRootPage({super.key});

  @override
  State<HomeRootPage> createState() => _HomeRootPageState();
}

class _HomeRootPageState extends State<HomeRootPage> {
  int _selectedIndex = 0;

  static const _tabs = [
    _HomeTabData(icon: CupertinoIcons.chat_bubble_2_fill, label: 'Chats'),
    _HomeTabData(icon: CupertinoIcons.gear_alt_fill, label: 'Settings'),
  ];

  late final List<Widget> _tabViews = const [
    CupertinoTabView(builder: _buildChatsTab),
    CupertinoTabView(builder: _buildSettingsTab),
  ];

  static Widget _buildChatsTab(BuildContext context) => const ChatPage();

  static Widget _buildSettingsTab(BuildContext context) => const SettingsPage();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.backgroundPrimary),
      child: Column(
        children: [
          Expanded(
            child: IndexedStack(index: _selectedIndex, children: _tabViews),
          ),
          _BottomNavBar(
            items: _tabs,
            selectedIndex: _selectedIndex,
            onTap: (index) {
              if (_selectedIndex == index) {
                return;
              }
              setState(() {
                _selectedIndex = index;
              });
            },
          ),
        ],
      ),
    );
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
          height: 45,
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
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(data.icon, size: 24, color: color),
              const SizedBox(height: 3),
              Text(
                data.label,
                style: TextStyle(
                  color: color,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
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
  const _HomeTabData({required this.icon, required this.label});

  final IconData icon;
  final String label;
}
