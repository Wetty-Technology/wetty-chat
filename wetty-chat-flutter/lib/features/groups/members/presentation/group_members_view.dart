import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/group_members_view_model.dart';

/// Page to display current group members and an "Add Member" button.
class GroupMembersPage extends ConsumerWidget {
  const GroupMembersPage({super.key, required this.chatId});

  final String chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(groupMembersViewModelProvider(chatId));
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Group Members'),
      ),
      child: SafeArea(
        child: membersAsync.when(
          loading: () => const Center(child: CupertinoActivityIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(error.toString(), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  CupertinoButton.filled(
                    onPressed: () => ref
                        .read(groupMembersViewModelProvider(chatId).notifier)
                        .reload(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
          data: (members) => Column(
            children: [
              Expanded(
                child: members.isEmpty
                    ? const Center(child: Text('No members'))
                    : ListView.builder(
                        itemCount: members.length,
                        itemBuilder: (context, index) {
                          final member = members[index];
                          final name = member.username ?? 'User ${member.uid}';
                          final initial = name.isNotEmpty
                              ? name[0].toUpperCase()
                              : '?';
                          final isAdmin = member.role.toLowerCase() == 'admin';
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: const BoxDecoration(
                                    color: CupertinoColors.systemGrey4,
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    initial,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: CupertinoColors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                      Text(
                                        member.role,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isAdmin
                                              ? CupertinoColors.activeBlue
                                              : CupertinoColors.secondaryLabel
                                                    .resolveFrom(context),
                                          fontWeight: isAdmin
                                              ? FontWeight.w600
                                              : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: CupertinoButton.filled(
                    onPressed: () {
                      // TODO: implement add member
                    },
                    child: const Text('Add Member'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
