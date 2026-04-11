import 'package:flutter/cupertino.dart';

import '../../../../../app/theme/style_config.dart';
import '../../../../groups/members/data/group_member_models.dart';

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
    final avatarImage = avatarUrl?.trim();
    if (avatarImage != null && avatarImage.isNotEmpty) {
      return ClipOval(
        child: Image.network(
          avatarImage,
          width: 30,
          height: 30,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _MentionAvatarFallback(displayName: displayName);
          },
        ),
      );
    }
    return _MentionAvatarFallback(displayName: displayName);
  }
}

class _MentionAvatarFallback extends StatelessWidget {
  const _MentionAvatarFallback({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final initial = (displayName.isNotEmpty ? displayName[0] : '?')
        .toUpperCase();
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: colors.avatarBackground,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: appOnDarkTextStyle(
          context,
          fontSize: AppFontSizes.bodySmall,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
