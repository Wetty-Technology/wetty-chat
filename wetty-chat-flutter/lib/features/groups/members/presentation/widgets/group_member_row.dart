import 'package:flutter/cupertino.dart';

import '../../../../shared/presentation/app_avatar.dart';
import '../../data/group_member_models.dart';

class GroupMemberRow extends StatelessWidget {
  const GroupMemberRow({
    super.key,
    required this.member,
    required this.displayName,
    required this.canManageMembers,
    required this.isCurrentUser,
    required this.onTap,
  });

  final GroupMember member;
  final String displayName;
  final bool canManageMembers;
  final bool isCurrentUser;
  final VoidCallback onTap;

  bool get _isInteractive => canManageMembers && !isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final labelColor = CupertinoColors.label.resolveFrom(context);
    final secondaryColor = CupertinoColors.secondaryLabel.resolveFrom(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _isInteractive ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _GroupMemberAvatar(member: member, displayName: displayName),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16, color: labelColor),
              ),
            ),
            const SizedBox(width: 12),
            _RoleChip(role: member.role),
            if (_isInteractive) ...[
              const SizedBox(width: 8),
              Icon(
                CupertinoIcons.chevron_forward,
                size: 18,
                color: secondaryColor,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GroupMemberAvatar extends StatelessWidget {
  const _GroupMemberAvatar({required this.member, required this.displayName});

  static const double _size = 40;

  final GroupMember member;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    return AppAvatar(
      name: displayName,
      imageUrl: member.avatarUrl,
      size: _size,
      memCacheWidth: 112,
      fallbackBackgroundColor: CupertinoColors.systemGrey4.resolveFrom(context),
      fallbackTextStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: CupertinoColors.white,
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == 'admin';
    final fillColor = isAdmin
        ? CupertinoColors.activeBlue
        : CupertinoColors.systemGrey4.resolveFrom(context);
    final textColor = isAdmin
        ? CupertinoColors.white
        : CupertinoColors.secondaryLabel.resolveFrom(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: fillColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          role,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
