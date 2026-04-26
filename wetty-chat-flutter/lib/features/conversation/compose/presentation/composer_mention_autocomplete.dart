import 'package:flutter/cupertino.dart';

import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/features/groups/members/data/group_member_models.dart';
import 'package:chahua/features/shared/presentation/app_avatar.dart';

class ComposerMentionAutocomplete extends StatelessWidget {
  const ComposerMentionAutocomplete({
    super.key,
    required this.results,
    required this.loading,
    required this.onSelect,
  });

  final List<GroupMember> results;
  final bool loading;
  final ValueChanged<GroupMember> onSelect;

  @override
  Widget build(BuildContext context) {
    if (!loading && results.isEmpty) {
      return const SizedBox.shrink();
    }

    final colors = context.appColors;

    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(color: colors.backgroundSecondary),
      child: loading && results.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CupertinoActivityIndicator()),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 6),
              shrinkWrap: true,
              itemCount: results.length,
              separatorBuilder: (context, index) {
                return Container(
                  height: 1,
                  margin: const EdgeInsets.only(left: 52, right: 12),
                  color: colors.inputBorder,
                );
              },
              itemBuilder: (context, index) {
                final member = results[index];
                final displayName = member.username?.trim().isNotEmpty == true
                    ? member.username!.trim()
                    : 'User ${member.uid}';
                return CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  onPressed: () => onSelect(member),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        _MentionAvatar(
                          avatarUrl: member.avatarUrl,
                          displayName: displayName,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: appTextStyle(
                              context,
                              fontSize: 14,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _MentionAvatar extends StatelessWidget {
  const _MentionAvatar({required this.avatarUrl, required this.displayName});

  final String? avatarUrl;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    return AppAvatar(
      name: displayName,
      imageUrl: avatarUrl,
      size: 30,
      memCacheWidth: 72,
      fallbackTextStyle: appOnDarkTextStyle(
        context,
        fontSize: AppFontSizes.bodySmall,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
