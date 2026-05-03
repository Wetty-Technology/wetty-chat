import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/core/session/current_user_profile.dart';
import 'package:chahua/core/session/dev_session_store.dart';
import 'package:chahua/features/shared/presentation/app_avatar.dart';
import 'package:chahua/l10n/app_localizations.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsProfileHero extends ConsumerWidget {
  const SettingsProfileHero({super.key});

  static const double _avatarSize = 88;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final session = ref.watch(authSessionProvider);
    final profileAsync = ref.watch(currentUserProfileProvider);
    final profile = profileAsync.maybeWhen(
      data: (profile) => profile,
      orElse: () => null,
    );
    final displayName = _displayName(l10n, profile, session.currentUserId);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Column(
        children: [
          AppAvatar(
            name: displayName,
            imageUrl: profile?.avatarUrl,
            size: _avatarSize,
            memCacheWidth: (_avatarSize * 2).round(),
          ),
          const SizedBox(height: 16),
          profileAsync.isLoading && profile == null
              ? Container(
                  width: 160,
                  height: 28,
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey4.resolveFrom(context),
                    borderRadius: BorderRadius.circular(999),
                  ),
                )
              : Text(
                  displayName,
                  textAlign: TextAlign.center,
                  style: appTextStyle(
                    context,
                    fontSize: 23,
                    fontWeight: AppFontWeights.bold,
                  ),
                ),
        ],
      ),
    );
  }

  String _displayName(
    AppLocalizations l10n,
    CurrentUserProfile? profile,
    int currentUserId,
  ) {
    final username = profile?.username.trim();
    if (username != null && username.isNotEmpty) {
      return username;
    }
    return l10n.userFallbackName(currentUserId);
  }
}
