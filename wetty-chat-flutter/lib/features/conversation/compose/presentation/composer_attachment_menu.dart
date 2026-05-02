import 'dart:async';

import 'package:flutter/cupertino.dart';

import 'package:chahua/features/conversation/compose/data/attachment_picker_service.dart';
import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/l10n/app_localizations.dart';

class ComposerAttachmentMenu extends StatelessWidget {
  const ComposerAttachmentMenu({super.key, required this.onPickAttachments});

  final Future<void> Function(ComposerAttachmentSource source)
  onPickAttachments;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return CupertinoPopupSurface(
      isSurfacePainted: false,
      child: Container(
        key: const ValueKey<String>('attachment-panel'),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.composerReplyPreviewSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.inputBorder.withAlpha(230)),
          boxShadow: [
            BoxShadow(
              color: CupertinoColors.black.withAlpha(22),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
            BoxShadow(
              color: CupertinoColors.black.withAlpha(34),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AttachmentSourceAction(
              label: AppLocalizations.of(context)!.photos,
              source: ComposerAttachmentSource.photos,
              showDivider: true,
              onTap: onPickAttachments,
            ),
            _AttachmentSourceAction(
              label: AppLocalizations.of(context)!.gifs,
              source: ComposerAttachmentSource.gifs,
              showDivider: true,
              onTap: onPickAttachments,
            ),
            _AttachmentSourceAction(
              label: AppLocalizations.of(context)!.videos,
              source: ComposerAttachmentSource.videos,
              showDivider: true,
              onTap: onPickAttachments,
            ),
            _AttachmentSourceAction(
              label: AppLocalizations.of(context)!.files,
              source: ComposerAttachmentSource.files,
              showDivider: false,
              onTap: onPickAttachments,
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentSourceAction extends StatelessWidget {
  const _AttachmentSourceAction({
    required this.label,
    required this.source,
    required this.showDivider,
    required this.onTap,
  });

  final String label;
  final ComposerAttachmentSource source;
  final bool showDivider;
  final Future<void> Function(ComposerAttachmentSource source) onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: colors.inputBorder))
            : null,
      ),
      child: CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        onPressed: () => unawaited(onTap(source)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _sourceIcon(source),
              size: 24,
              color: CupertinoColors.activeBlue.resolveFrom(context),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.left,
                style: appTextStyle(
                  context,
                  fontWeight: AppFontWeights.semibold,
                  fontSize: AppFontSizes.body,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _sourceIcon(ComposerAttachmentSource source) {
    return switch (source) {
      ComposerAttachmentSource.photos => CupertinoIcons.photo_on_rectangle,
      ComposerAttachmentSource.gifs => CupertinoIcons.sparkles,
      ComposerAttachmentSource.videos => CupertinoIcons.videocam_fill,
      ComposerAttachmentSource.files => CupertinoIcons.doc_fill,
    };
  }
}
