import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chahua/app/theme/style_config.dart';
import '../../../../core/session/dev_session_store.dart';
import '../application/group_members_view_model.dart';
import '../data/group_member_models.dart';
import 'widgets/group_member_actions.dart';
import 'widgets/group_members_body.dart';

/// Page to display current group members and admin member actions.
class GroupMembersPage extends ConsumerStatefulWidget {
  const GroupMembersPage({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<GroupMembersPage> createState() => _GroupMembersPageState();
}

class _GroupMembersPageState extends ConsumerState<GroupMembersPage> {
  static const Duration _searchDebounce = Duration(milliseconds: 250);

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounceTimer;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final viewState = ref.read(groupMembersViewModelProvider(widget.chatId));
    final members = viewState.value;
    if (members == null || !members.hasMore || members.isLoadingMore) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      ref
          .read(groupMembersViewModelProvider(widget.chatId).notifier)
          .loadMore();
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(_searchDebounce, () {
      ref
          .read(groupMembersViewModelProvider(widget.chatId).notifier)
          .updateSearchQuery(value);
    });
  }

  Future<void> _submitSearch(String value) async {
    _searchDebounceTimer?.cancel();
    await ref
        .read(groupMembersViewModelProvider(widget.chatId).notifier)
        .updateSearchQuery(value, mode: GroupMemberSearchMode.submitted);
  }

  void _showToast(String message) {
    final overlay = Navigator.of(context).overlay;
    if (overlay == null) {
      return;
    }

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        left: 24,
        right: 24,
        bottom: 80,
        child: _ToastWidget(message: message, onDismiss: () => entry.remove()),
      ),
    );
    overlay.insert(entry);
  }

  Future<void> _handleRemoveMember(GroupMember member) async {
    final displayName = _displayName(member);
    final confirmed = await GroupMemberActions.confirmAction(
      context,
      title: 'Remove Member',
      message: 'Remove $displayName from this group?',
      confirmLabel: 'Remove',
      isDestructive: true,
    );
    if (!confirmed) {
      return;
    }

    try {
      await ref
          .read(groupMembersViewModelProvider(widget.chatId).notifier)
          .removeMember(member.uid);
      if (!mounted) {
        return;
      }
      _showToast('Member removed');
    } catch (error) {
      if (!mounted) {
        return;
      }
      await GroupMemberActions.showErrorDialog(context, '$error');
    }
  }

  Future<void> _handleToggleRole(GroupMember member) async {
    final nextRole = member.role == 'admin' ? 'member' : 'admin';
    final isPromoting = nextRole == 'admin';
    final displayName = _displayName(member);
    final confirmed = await GroupMemberActions.confirmAction(
      context,
      title: isPromoting ? 'Promote Member' : 'Demote Member',
      message: isPromoting
          ? 'Promote $displayName to admin?'
          : 'Demote $displayName to member?',
      confirmLabel: isPromoting ? 'Promote' : 'Demote',
    );
    if (!confirmed) {
      return;
    }

    try {
      await ref
          .read(groupMembersViewModelProvider(widget.chatId).notifier)
          .updateMemberRole(member.uid, role: nextRole);
      if (!mounted) {
        return;
      }
      _showToast(isPromoting ? 'Member promoted' : 'Member demoted');
    } catch (error) {
      if (!mounted) {
        return;
      }
      await GroupMemberActions.showErrorDialog(context, '$error');
    }
  }

  Future<void> _handleMemberTap(
    GroupMember member, {
    required bool canManageMembers,
    required int currentUserId,
  }) async {
    if (!canManageMembers || member.uid == currentUserId) {
      return;
    }

    await GroupMemberActions.showMemberActions(
      context,
      member: member,
      onToggleRole: () => _handleToggleRole(member),
      onRemoveMember: () => _handleRemoveMember(member),
    );
  }

  String _displayName(GroupMember member) {
    final username = member.username?.trim();
    if (username != null && username.isNotEmpty) {
      return username;
    }
    return 'User ${member.uid}';
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(
      groupMembersViewModelProvider(widget.chatId),
    );
    final currentUserId = ref.watch(authSessionProvider).currentUserId;

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Group Members'),
      ),
      child: SafeArea(
        child: GroupMembersBody(
          membersAsync: membersAsync,
          searchController: _searchController,
          scrollController: _scrollController,
          currentUserId: currentUserId,
          onSearchChanged: _onSearchChanged,
          onSearchSubmitted: _submitSearch,
          onRetry: () => ref
              .read(groupMembersViewModelProvider(widget.chatId).notifier)
              .reload(),
          onMemberTap: (member, canManageMembers) => _handleMemberTap(
            member,
            canManageMembers: canManageMembers,
            currentUserId: currentUserId,
          ),
          displayNameFor: _displayName,
        ),
      ),
    );
  }
}

class _ToastWidget extends StatefulWidget {
  const _ToastWidget({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> {
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _dismissTimer = Timer(const Duration(seconds: 2), widget.onDismiss);
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          widget.message,
          textAlign: TextAlign.center,
          style: appBodyTextStyle(context, color: CupertinoColors.white),
        ),
      ),
    );
  }
}
