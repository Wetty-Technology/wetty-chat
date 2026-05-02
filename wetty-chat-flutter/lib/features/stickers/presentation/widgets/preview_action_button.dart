import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chahua/app/theme/style_config.dart';
import '../../../../core/session/dev_session_store.dart';
import '../../application/sticker_detail_view_model.dart';

class PreviewActionButton extends ConsumerWidget {
  const PreviewActionButton({
    super.key,
    required this.state,
    required this.stickerId,
    required this.onToggleSubscription,
    required this.onManagePack,
  });

  final StickerDetailState state;
  final String stickerId;
  final VoidCallback onToggleSubscription;
  final ValueChanged<String> onManagePack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pack = state.pack;
    if (pack == null) return const SizedBox.shrink();

    final currentUserId = ref.watch(devSessionProvider);
    final isOwner = pack.ownerUid == currentUserId;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SizedBox(
        width: double.infinity,
        child: isOwner
            ? CupertinoButton.filled(
                onPressed: () => onManagePack(pack.id),
                child: const Text('Manage'),
              )
            : state.isSubscribed
            ? CupertinoButton(
                color: CupertinoColors.destructiveRed.withAlpha(30),
                onPressed: onToggleSubscription,
                child: Text(
                  'Unsubscribe',
                  style: appBodyTextStyle(
                    context,
                    color: CupertinoColors.destructiveRed,
                  ),
                ),
              )
            : CupertinoButton.filled(
                onPressed: onToggleSubscription,
                child: const Text('Subscribe'),
              ),
      ),
    );
  }
}
