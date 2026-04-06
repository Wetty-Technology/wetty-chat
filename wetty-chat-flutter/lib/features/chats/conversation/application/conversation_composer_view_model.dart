import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/conversation_repository.dart';
import '../models/conversation_models.dart';

sealed class ConversationComposerMode {
  const ConversationComposerMode();
}

class ComposerIdle extends ConversationComposerMode {
  const ComposerIdle();
}

class ComposerReplying extends ConversationComposerMode {
  const ComposerReplying(this.message);

  final ConversationMessage message;
}

class ComposerEditing extends ConversationComposerMode {
  const ComposerEditing(this.message);

  final ConversationMessage message;
}

class ComposerAttachment {
  const ComposerAttachment({
    required this.id,
    required this.name,
    required this.mimeType,
    this.previewBytes,
  });

  final String id;
  final String name;
  final String mimeType;
  final Uint8List? previewBytes;

  bool get isImage => mimeType.startsWith('image/') && previewBytes != null;
}

typedef ConversationComposerState = ({
  String draft,
  ConversationComposerMode mode,
  List<ComposerAttachment> attachments,
});

class ConversationComposerViewModel
    extends FamilyNotifier<ConversationComposerState, ConversationScope> {
  late final ConversationRepository _repository;

  @override
  ConversationComposerState build(ConversationScope arg) {
    _repository = ref.read(conversationRepositoryProvider(arg));
    return (
      draft: _repository.draft,
      mode: const ComposerIdle(),
      attachments: const <ComposerAttachment>[],
    );
  }

  void setDraft(String text) {
    _repository.cacheDraft(text);
    state = (draft: text, mode: state.mode, attachments: state.attachments);
  }

  void setReplyTo(ConversationMessage message) {
    state = (
      draft: state.draft,
      mode: ComposerReplying(message),
      attachments: state.attachments,
    );
  }

  void startEditing(ConversationMessage message) {
    state = (
      draft: message.message ?? '',
      mode: ComposerEditing(message),
      attachments: const <ComposerAttachment>[],
    );
    _repository.cacheDraft(message.message ?? '');
  }

  void clearMode() {
    state = (
      draft: state.draft,
      mode: const ComposerIdle(),
      attachments: state.attachments,
    );
  }

  void addAttachment(ComposerAttachment attachment) {
    state = (
      draft: state.draft,
      mode: state.mode,
      attachments: [...state.attachments, attachment],
    );
  }

  void removeAttachmentAt(int index) {
    if (index < 0 || index >= state.attachments.length) {
      return;
    }
    final attachments = [...state.attachments]..removeAt(index);
    state = (draft: state.draft, mode: state.mode, attachments: attachments);
  }

  void clearAttachments() {
    state = (
      draft: state.draft,
      mode: state.mode,
      attachments: const <ComposerAttachment>[],
    );
  }

  Future<void> submit() async {
    final text = state.draft.trim();
    final attachmentIds = state.attachments
        .map((attachment) => attachment.id)
        .toList();
    switch (state.mode) {
      case ComposerEditing(:final message):
        await _repository.editMessage(message.serverId!, text);
      case ComposerReplying(:final message):
        await _repository.sendMessage(
          text,
          replyToId: message.serverId,
          attachmentIds: attachmentIds,
        );
      case ComposerIdle():
        await _repository.sendMessage(text, attachmentIds: attachmentIds);
    }
    _repository.cacheDraft('');
    state = (
      draft: '',
      mode: const ComposerIdle(),
      attachments: const <ComposerAttachment>[],
    );
  }

  Future<void> deleteMessage(int messageId) {
    return _repository.deleteMessage(messageId);
  }
}

final conversationComposerViewModelProvider =
    NotifierProvider.family<
      ConversationComposerViewModel,
      ConversationComposerState,
      ConversationScope
    >(ConversationComposerViewModel.new);
