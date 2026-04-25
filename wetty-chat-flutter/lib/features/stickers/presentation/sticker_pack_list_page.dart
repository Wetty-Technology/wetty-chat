import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/route_names.dart';
import '../../../app/theme/style_config.dart';
import '../../../core/session/dev_session_store.dart';
import 'package:chahua/features/shared/presentation/sticker_image_widget.dart';
import '../application/sticker_pack_list_view_model.dart';
import '../models/sticker_models.dart';

class StickerPackListPage extends ConsumerStatefulWidget {
  const StickerPackListPage({super.key});

  @override
  ConsumerState<StickerPackListPage> createState() =>
      _StickerPackListPageState();
}

class _StickerPackListPageState extends ConsumerState<StickerPackListPage> {
  @override
  void initState() {
    super.initState();
    Future(() {
      ref.read(stickerPackListViewModelProvider.notifier).loadPacks();
    });
  }

  void _showCreatePackDialog() {
    final controller = TextEditingController();
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('New Sticker Pack'),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: CupertinoTextField(
            controller: controller,
            placeholder: 'Pack name',
            autofocus: true,
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              final pack = await ref
                  .read(stickerPackListViewModelProvider.notifier)
                  .createPack(name);
              if (pack != null && mounted) {
                context.push(AppRoutes.settingsStickerPackDetail(pack.id));
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(stickerPackListViewModelProvider);
    final currentUserId = ref.watch(devSessionProvider);
    final colors = context.appColors;

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Sticker Packs'),
      ),
      child: SafeArea(
        child: state.isLoading && state.packs.isEmpty
            ? const Center(child: CupertinoActivityIndicator())
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: CupertinoListTile(
                      leading: Icon(
                        CupertinoIcons.add_circled,
                        color: colors.accentPrimary,
                      ),
                      title: Text(
                        'Create New Pack',
                        style: TextStyle(color: colors.accentPrimary),
                      ),
                      onTap: _showCreatePackDialog,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Container(height: 0.5, color: colors.separator),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final pack = state.packs[index];
                      return _PackListTile(
                        pack: pack,
                        isOwned: pack.ownerUid == currentUserId,
                        onTap: () {
                          context.push(
                            AppRoutes.settingsStickerPackDetail(pack.id),
                          );
                        },
                      );
                    }, childCount: state.packs.length),
                  ),
                ],
              ),
      ),
    );
  }
}

class _PackListTile extends StatelessWidget {
  const _PackListTile({
    required this.pack,
    required this.isOwned,
    required this.onTap,
  });

  final StickerPackSummary pack;
  final bool isOwned;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return CupertinoListTile(
      leading: pack.previewSticker != null
          ? StickerImage(
              media: pack.previewSticker!.media,
              emoji: pack.previewSticker!.emoji,
              size: 32,
            )
          : Icon(CupertinoIcons.cube, size: 32, color: colors.textSecondary),
      title: Text(
        pack.name,
        style: appTextStyle(context, fontSize: AppFontSizes.body),
      ),
      subtitle: Text(
        '${pack.stickerCount} stickers',
        style: appSecondaryTextStyle(context, fontSize: AppFontSizes.bodySmall),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isOwned)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colors.accentPrimary.withAlpha(25),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Owned',
                style: TextStyle(
                  color: colors.accentPrimary,
                  fontSize: AppFontSizes.meta,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          const SizedBox(width: 4),
          Icon(
            CupertinoIcons.chevron_forward,
            size: 14,
            color: colors.textSecondary,
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}
