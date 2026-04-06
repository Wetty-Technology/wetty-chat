import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/session/dev_session_store.dart';
import '../../models/message_models.dart';
import '../data/conversation_repository.dart';
import '../domain/conversation_message.dart';
import '../domain/conversation_scope.dart';
import 'conversation_draft_store.dart';

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

  AttachmentItem toAttachmentItem() =>
      AttachmentItem(id: id, url: '', kind: mimeType, size: 0, fileName: name);
}

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

class ConversationComposerState {
  const ConversationComposerState({
    required this.draft,
    required this.mode,
    required this.attachments,
  });

  final String draft;
  final ConversationComposerMode mode;
  final List<ComposerAttachment> attachments;

  bool get isEditing => mode is ComposerEditing;

  ConversationComposerState copyWith({
    String? draft,
    ConversationComposerMode? mode,
    List<ComposerAttachment>? attachments,
  }) {
    return ConversationComposerState(
      draft: draft ?? this.draft,
      mode: mode ?? this.mode,
      attachments: attachments ?? this.attachments,
    );
  }
}

class ConversationComposerViewModel
    extends FamilyNotifier<ConversationComposerState, ConversationScope> {
  late final ConversationRepository _repository;
  late final ConversationDraftStore _draftStore;
  late final ConversationScope _scope;

  @override
  ConversationComposerState build(ConversationScope arg) {
    _scope = arg;
    _repository = ref.read(conversationRepositoryProvider(arg));
    _draftStore = ref.read(conversationDraftProvider);
    final draft = _draftStore.getDraft(arg) ?? '';
    return ConversationComposerState(
      draft: draft,
      mode: const ComposerIdle(),
      attachments: const <ComposerAttachment>[],
    );
  }

  Future<void> updateDraft(String value) async {
    state = state.copyWith(draft: value);
    await _draftStore.setDraft(_scope, value);
  }

  void beginReply(ConversationMessage message) {
    state = state.copyWith(
      mode: ComposerReplying(message),
      attachments: const <ComposerAttachment>[],
    );
  }

  void beginEdit(ConversationMessage message) {
    state = state.copyWith(
      mode: ComposerEditing(message),
      draft: message.message ?? '',
      attachments: const <ComposerAttachment>[],
    );
  }

  void clearMode() {
    state = state.copyWith(mode: const ComposerIdle());
  }

  void addUploadedAttachment(ComposerAttachment attachment) {
    state = state.copyWith(attachments: [...state.attachments, attachment]);
  }

  void removeAttachmentAt(int index) {
    if (index < 0 || index >= state.attachments.length) {
      return;
    }
    final next = [...state.attachments]..removeAt(index);
    state = state.copyWith(attachments: next);
  }

  void clearAttachments() {
    if (state.attachments.isEmpty) {
      return;
    }
    state = state.copyWith(attachments: const <ComposerAttachment>[]);
  }

  Future<void> send({required String text}) async {
    final trimmed = text.trim();
    final attachmentIds = state.attachments.map((item) => item.id).toList();
    final mode = state.mode;
    if (trimmed.isEmpty && attachmentIds.isEmpty) {
      return;
    }

    if (mode is ComposerEditing) {
      if (attachmentIds.isNotEmpty) {
        throw Exception('Editing messages does not support attachments');
      }
      _repository.beginOptimisticEdit(mode.message.serverMessageId!);
      try {
        await _repository.commitEdit(mode.message.serverMessageId!, trimmed);
        state = const ConversationComposerState(
          draft: '',
          mode: ComposerIdle(),
          attachments: <ComposerAttachment>[],
        );
        await _draftStore.clearDraft(_scope);
      } catch (_) {
        _repository.rollbackEdit(mode.message.serverMessageId!);
        rethrow;
      }
      return;
    }

    final currentUserId = ref.read(devSessionProvider);
    final clientGeneratedId =
        '${DateTime.now().microsecondsSinceEpoch}-$currentUserId-${_scope.storageKey}';
    _repository.insertOptimisticSend(
      sender: Sender(uid: currentUserId, name: 'You'),
      text: trimmed,
      attachments: state.attachments
          .map((item) => item.toAttachmentItem())
          .toList(),
      clientGeneratedId: clientGeneratedId,
      replyToId: mode is ComposerReplying ? mode.message.serverMessageId : null,
    );

    try {
      await _repository.commitSend(
        clientGeneratedId: clientGeneratedId,
        text: trimmed,
        attachmentIds: attachmentIds,
        replyToId: mode is ComposerReplying
            ? mode.message.serverMessageId
            : null,
      );
      state = const ConversationComposerState(
        draft: '',
        mode: ComposerIdle(),
        attachments: <ComposerAttachment>[],
      );
      await _draftStore.clearDraft(_scope);
    } catch (_) {
      _repository.markSendFailed(clientGeneratedId);
      rethrow;
    }
  }

  Future<void> delete(ConversationMessage message) async {
    final messageId = message.serverMessageId;
    if (messageId == null) {
      _repository.discardFailedMessage(message);
      return;
    }
    _repository.beginOptimisticDelete(messageId);
    try {
      await _repository.commitDelete(messageId);
    } catch (_) {
      _repository.rollbackDelete(messageId);
      rethrow;
    }
  }

  Future<void> retryFailedMessage(ConversationMessage message) async {
    await _repository.retryFailedSend(message);
  }

  Future<void> discardFailedMessage(ConversationMessage message) async {
    _repository.discardFailedMessage(message);
  }
}

final conversationComposerViewModelProvider =
    NotifierProvider.family<
      ConversationComposerViewModel,
      ConversationComposerState,
      ConversationScope
    >(ConversationComposerViewModel.new);
