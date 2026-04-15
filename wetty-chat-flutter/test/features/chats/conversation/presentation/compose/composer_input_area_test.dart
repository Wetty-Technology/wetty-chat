import 'dart:typed_data';

import 'package:chahua/features/chats/conversation/application/conversation_composer_view_model.dart';
import 'package:chahua/features/chats/conversation/data/attachment_picker_service.dart';
import 'package:chahua/features/chats/conversation/presentation/compose/composer_audio_controls.dart';
import 'package:chahua/features/chats/conversation/presentation/compose/composer_input_area.dart';
import 'package:chahua/l10n/app_localizations.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'composer preview cards use media aspect ratio for images and videos',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        CupertinoApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CupertinoPageScaffold(
            child: ComposerInputArea(
              composer: ConversationComposerState(
                draft: '',
                mode: const ComposerIdle(),
                attachments: [
                  _attachment(
                    localId: 'wide-image',
                    kind: ComposerAttachmentKind.image,
                    width: 600,
                    height: 200,
                  ),
                  _attachment(
                    localId: 'tall-image',
                    kind: ComposerAttachmentKind.image,
                    width: 200,
                    height: 600,
                  ),
                  _attachment(
                    localId: 'wide-video',
                    kind: ComposerAttachmentKind.video,
                    width: 640,
                    height: 360,
                  ),
                  _attachment(
                    localId: 'tall-video',
                    kind: ComposerAttachmentKind.video,
                    width: 360,
                    height: 640,
                  ),
                ],
                audioDraft: null,
                savedDraftBeforeEdit: null,
                nextClientGeneratedId: 'next-id',
              ),
              textController: TextEditingController(),
              focusNode: FocusNode(),
              inputScrollController: ScrollController(),
              snapPosition: ComposerAudioSnapPosition.origin,
              fieldMinHeight: 44,
              onDraftChanged: (_) {},
              onSend: () async {},
              onRemoveAttachment: (_) {},
              onRetryAttachment: (_) async {},
              onDeleteAudioDraft: () async {},
              onToggleStickerPicker: () {},
              isStickerPickerOpen: false,
            ),
          ),
        ),
      );
      await tester.pump();

      final wideImageSize = tester.getSize(
        find.byKey(const ValueKey('composer-attachment-card-wide-image')),
      );
      final tallImageSize = tester.getSize(
        find.byKey(const ValueKey('composer-attachment-card-tall-image')),
      );
      final wideVideoSize = tester.getSize(
        find.byKey(const ValueKey('composer-attachment-card-wide-video')),
      );
      final tallVideoSize = tester.getSize(
        find.byKey(const ValueKey('composer-attachment-card-tall-video')),
      );

      expect(wideImageSize.width, greaterThan(wideImageSize.height));
      expect(tallImageSize.height, greaterThan(tallImageSize.width));
      expect(wideVideoSize.width, greaterThan(wideVideoSize.height));
      expect(tallVideoSize.height, greaterThan(tallVideoSize.width));
      expect(wideImageSize.width, greaterThan(tallImageSize.width));
      expect(wideVideoSize.width, greaterThan(tallVideoSize.width));
    },
  );

  testWidgets('composer file attachments keep the fallback square card', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: CupertinoPageScaffold(
          child: ComposerInputArea(
            composer: ConversationComposerState(
              draft: '',
              mode: const ComposerIdle(),
              attachments: [
                _attachment(
                  localId: 'file-card',
                  kind: ComposerAttachmentKind.file,
                ),
              ],
              audioDraft: null,
              savedDraftBeforeEdit: null,
              nextClientGeneratedId: 'next-id',
            ),
            textController: TextEditingController(),
            focusNode: FocusNode(),
            inputScrollController: ScrollController(),
            snapPosition: ComposerAudioSnapPosition.origin,
            fieldMinHeight: 44,
            onDraftChanged: (_) {},
            onSend: () async {},
            onRemoveAttachment: (_) {},
            onRetryAttachment: (_) async {},
            onDeleteAudioDraft: () async {},
            onToggleStickerPicker: () {},
            isStickerPickerOpen: false,
          ),
        ),
      ),
    );
    await tester.pump();

    final fileCardSize = tester.getSize(
      find.byKey(const ValueKey('composer-attachment-card-file-card')),
    );

    expect(fileCardSize.width, 116);
    expect(fileCardSize.height, 116);
  });
}

ComposerAttachment _attachment({
  required String localId,
  required ComposerAttachmentKind kind,
  int? width,
  int? height,
}) {
  return ComposerAttachment(
    localId: localId,
    file: PlatformFile(
      name: '$localId.bin',
      size: 1024,
      path: '/tmp/$localId.bin',
      bytes: kind == ComposerAttachmentKind.file
          ? null
          : Uint8List.fromList(_transparentImage),
    ),
    name: '$localId.bin',
    mimeType: switch (kind) {
      ComposerAttachmentKind.image => 'image/jpeg',
      ComposerAttachmentKind.gif => 'image/gif',
      ComposerAttachmentKind.video => 'video/mp4',
      ComposerAttachmentKind.file => 'application/octet-stream',
    },
    kind: kind,
    sizeBytes: 1024,
    previewBytes: kind == ComposerAttachmentKind.file
        ? null
        : Uint8List.fromList(_transparentImage),
    width: width,
    height: height,
    status: ComposerAttachmentUploadStatus.queued,
  );
}

const List<int> _transparentImage = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];
