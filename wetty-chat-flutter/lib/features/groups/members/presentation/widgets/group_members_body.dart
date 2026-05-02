import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chahua/app/theme/style_config.dart';
import '../../application/group_members_view_model.dart';
import '../../data/group_member_models.dart';
import 'group_member_row.dart';

class GroupMembersBody extends StatelessWidget {
  const GroupMembersBody({
    super.key,
    required this.membersAsync,
    required this.searchController,
    required this.scrollController,
    required this.currentUserId,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onRetry,
    required this.onMemberTap,
    required this.displayNameFor,
  });

  final AsyncValue<GroupMembersViewState> membersAsync;
  final TextEditingController searchController;
  final ScrollController scrollController;
  final int currentUserId;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onRetry;
  final void Function(GroupMember member, bool canManageMembers) onMemberTap;
  final String Function(GroupMember member) displayNameFor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: CupertinoSearchTextField(
            controller: searchController,
            placeholder: 'Search members',
            onChanged: onSearchChanged,
            onSubmitted: onSearchSubmitted,
          ),
        ),
        Expanded(
          child: membersAsync.when(
            loading: () => const Center(child: CupertinoActivityIndicator()),
            error: (error, _) =>
                _ErrorState(error: error.toString(), onRetry: onRetry),
            data: (viewState) => _MembersList(
              viewState: viewState,
              scrollController: scrollController,
              currentUserId: currentUserId,
              onMemberTap: onMemberTap,
              displayNameFor: displayNameFor,
            ),
          ),
        ),
      ],
    );
  }
}

class _MembersList extends StatelessWidget {
  const _MembersList({
    required this.viewState,
    required this.scrollController,
    required this.currentUserId,
    required this.onMemberTap,
    required this.displayNameFor,
  });

  final GroupMembersViewState viewState;
  final ScrollController scrollController;
  final int currentUserId;
  final void Function(GroupMember member, bool canManageMembers) onMemberTap;
  final String Function(GroupMember member) displayNameFor;

  @override
  Widget build(BuildContext context) {
    if (viewState.members.isEmpty) {
      return _MembersEmptyState(hasSearch: viewState.searchQuery.isNotEmpty);
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 16),
      itemCount: viewState.members.length + (viewState.isLoadingMore ? 1 : 0),
      separatorBuilder: (context, index) => const _MemberDivider(),
      itemBuilder: (context, index) {
        if (index >= viewState.members.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CupertinoActivityIndicator()),
          );
        }

        final member = viewState.members[index];
        return GroupMemberRow(
          member: member,
          displayName: displayNameFor(member),
          canManageMembers: viewState.canManageMembers,
          isCurrentUser: member.uid == currentUserId,
          onTap: () => onMemberTap(member, viewState.canManageMembers),
        );
      },
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            CupertinoButton.filled(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MembersEmptyState extends StatelessWidget {
  const _MembersEmptyState({required this.hasSearch});

  final bool hasSearch;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          hasSearch ? 'No matching members found.' : 'No members found.',
          textAlign: TextAlign.center,
          style: appBodyTextStyle(
            context,
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
      ),
    );
  }
}

class _MemberDivider extends StatelessWidget {
  const _MemberDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 68),
      child: Container(
        height: 0.5,
        color: CupertinoColors.separator.resolveFrom(context),
      ),
    );
  }
}
