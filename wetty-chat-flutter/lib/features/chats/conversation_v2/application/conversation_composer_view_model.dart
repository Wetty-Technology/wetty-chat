import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';

import 'package:chahua/features/chats/models/message_models.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:voice_message/voice_message.dart';

import 'package:chahua/core/network/dio_client.dart';
import 'package:chahua/core/session/dev_session_store.dart';
import 'package:chahua/features/chats/conversation/domain/conversation_message.dart';
import 'package:chahua/features/chats/conversation/data/attachment_picker_service.dart';
import 'package:chahua/features/chats/conversation/data/attachment_service.dart';
import 'package:chahua/features/chats/conversation/data/audio_recorder_service.dart';
import 'package:chahua/features/chats/conversation/data/audio_waveform_cache_service.dart';
import 'package:chahua/features/chats/conversation/data/conversation_repository.dart';
import 'package:chahua/features/chats/conversation/domain/conversation_scope.dart';
import 'package:chahua/features/chats/conversation_v2/domain/conversation_message_v2.dart';
import 'package:chahua/features/chats/conversation_v2/domain/conversation_timeline_v2_identity.dart';
import 'package:chahua/features/chats/conversation/application/conversation_local_mutation_registry.dart';
import 'package:chahua/features/chats/conversation/application/conversation_draft_store.dart';
import 'package:chahua/features/chats/conversation_v2/data/conversation_timeline_v2_repository.dart';

const int composerMaxAttachments =
    ConversationComposerState.maxAttachmentsPerMessage;
const Duration composerMinAudioDuration = Duration(milliseconds: 500);

enum ComposerAttachmentUploadStatus { queued, uploading, uploaded, failed }

enum ComposerAudioDraftPhase {
  requestingPermission,
  recording,
  recorded,
  uploading,
}

enum ComposerAudioErrorCode {
  unsupported,
  permissionDenied,
  tooShort,
  startFailed,
  uploadFailed,
}

class ComposerAudioException implements Exception {
  const ComposerAudioException(this.code);

  final ComposerAudioErrorCode code;

  @override
  String toString() => 'ComposerAudioException($code)';
}

class ComposerAudioDraft {
  const ComposerAudioDraft({
    required this.path,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.duration,
    required this.phase,
    this.waveformSamples = const <int>[],
    this.progress = 0,
  });

  final String path;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final Duration duration;
  final ComposerAudioDraftPhase phase;
  final List<int> waveformSamples;
  final double progress;

  bool get isUploading => phase == ComposerAudioDraftPhase.uploading;
  bool get isRecording =>
      phase == ComposerAudioDraftPhase.requestingPermission ||
      phase == ComposerAudioDraftPhase.recording;
  bool get isRecorded => phase == ComposerAudioDraftPhase.recorded;

  ComposerAudioDraft copyWith({
    String? path,
    String? fileName,
    String? mimeType,
    int? sizeBytes,
    Duration? duration,
    ComposerAudioDraftPhase? phase,
    List<int>? waveformSamples,
    double? progress,
  }) {
    return ComposerAudioDraft(
      path: path ?? this.path,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      duration: duration ?? this.duration,
      phase: phase ?? this.phase,
      waveformSamples: waveformSamples ?? this.waveformSamples,
      progress: progress ?? this.progress,
    );
  }

  AttachmentItem toAttachmentItem({required String attachmentId}) =>
      AttachmentItem(
        id: attachmentId,
        url: '',
        kind: mimeType,
        size: sizeBytes,
        fileName: fileName,
        durationMs: duration.inMilliseconds,
        waveformSamples: waveformSamples,
      );
}

class ComposerAttachment {
  const ComposerAttachment({
    required this.localId,
    required this.file,
    required this.name,
    required this.mimeType,
    required this.kind,
    required this.sizeBytes,
    required this.status,
    this.previewBytes,
    this.width,
    this.height,
    this.progress = 0,
    this.attachmentId,
    this.errorMessage,
  });

  /// Local-only key used to track draft attachments before the backend assigns
  /// a persistent attachment id.
  final String localId;
  final PlatformFile file;
  final String name;
  final String mimeType;
  final ComposerAttachmentKind kind;
  final int sizeBytes;
  final Uint8List? previewBytes;
  final int? width;
  final int? height;
  final ComposerAttachmentUploadStatus status;
  final double progress;

  /// Backend attachment id returned after requesting the upload URL.
  final String? attachmentId;
  final String? errorMessage;

  bool get isImageLike =>
      kind == ComposerAttachmentKind.image ||
      kind == ComposerAttachmentKind.gif;
  bool get isVideo => kind == ComposerAttachmentKind.video;
  bool get isUploaded => status == ComposerAttachmentUploadStatus.uploaded;
  bool get isUploading => status == ComposerAttachmentUploadStatus.uploading;
  bool get isQueued => status == ComposerAttachmentUploadStatus.queued;
  bool get hasFailed => status == ComposerAttachmentUploadStatus.failed;
  bool get isFailed => hasFailed;

  ComposerAttachment copyWith({
    String? localId,
    PlatformFile? file,
    String? name,
    String? mimeType,
    ComposerAttachmentKind? kind,
    int? sizeBytes,
    Uint8List? previewBytes,
    int? width,
    int? height,
    ComposerAttachmentUploadStatus? status,
    double? progress,
    String? attachmentId,
    String? errorMessage,
    bool clearAttachmentId = false,
    bool clearErrorMessage = false,
  }) {
    return ComposerAttachment(
      localId: localId ?? this.localId,
      file: file ?? this.file,
      name: name ?? this.name,
      mimeType: mimeType ?? this.mimeType,
      kind: kind ?? this.kind,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      previewBytes: previewBytes ?? this.previewBytes,
      width: width ?? this.width,
      height: height ?? this.height,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      attachmentId: clearAttachmentId
          ? null
          : (attachmentId ?? this.attachmentId),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }

  AttachmentItem toAttachmentItem() => AttachmentItem(
    id: attachmentId ?? localId,
    url: '',
    kind: mimeType,
    size: sizeBytes,
    fileName: name,
    width: width,
    height: height,
  );
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

class _ComposerSendRequest {
  const _ComposerSendRequest({
    required this.sender,
    required this.text,
    required this.messageType,
    required this.optimisticAttachments,
    required this.attachmentIds,
    this.replyToId,
    this.sticker,
    this.stickerId,
  });

  final Sender sender;
  final String text;
  final String messageType;
  final List<AttachmentItem> optimisticAttachments;
  final List<String> attachmentIds;
  final int? replyToId;
  final StickerSummary? sticker;
  final String? stickerId;
}

class ConversationComposerState {
  const ConversationComposerState({
    required this.draft,
    required this.mode,
    required this.attachments,
    required this.audioDraft,
    required this.savedDraftBeforeEdit,
    required this.nextClientGeneratedId,
  });

  static const int maxAttachmentsPerMessage = 10;

  final String draft;
  final ConversationComposerMode mode;
  final List<ComposerAttachment> attachments;
  final ComposerAudioDraft? audioDraft;
  final String? savedDraftBeforeEdit;
  final String nextClientGeneratedId;

  bool get isEditing => mode is ComposerEditing;
  bool get hasUploadingAttachments =>
      attachments.any((item) => item.isUploading);
  bool get hasPendingAttachmentUploads =>
      attachments.any((item) => item.isQueued || item.isUploading);
  bool get hasFailedAttachments => attachments.any((item) => item.hasFailed);
  bool get hasUploadedAttachments => attachments.any((item) => item.isUploaded);
  bool get hasAudioDraft => audioDraft != null;
  bool get hasPendingAudioRecording =>
      audioDraft?.phase == ComposerAudioDraftPhase.requestingPermission ||
      audioDraft?.phase == ComposerAudioDraftPhase.recording;
  bool get hasRecordedAudioDraft =>
      audioDraft?.phase == ComposerAudioDraftPhase.recorded;
  bool get hasUploadingAudioDraft =>
      audioDraft?.phase == ComposerAudioDraftPhase.uploading;
  bool get hasAttachmentCapacity =>
      attachments.length < maxAttachmentsPerMessage;
  bool get isAtAttachmentLimit =>
      attachments.length >= maxAttachmentsPerMessage;
  bool get canSend =>
      !hasPendingAttachmentUploads &&
      !hasFailedAttachments &&
      (draft.trim().isNotEmpty || hasUploadedAttachments);
  bool get canStartAudio =>
      draft.trim().isEmpty &&
      attachments.isEmpty &&
      !isEditing &&
      !hasPendingAttachmentUploads &&
      !hasFailedAttachments &&
      audioDraft == null;
  int get remainingAttachmentSlots =>
      maxAttachmentsPerMessage - attachments.length;
  List<String> get uploadedAttachmentIds => attachments
      .where((item) => item.isUploaded && item.attachmentId != null)
      .map((item) => item.attachmentId!)
      .toList(growable: false);

  ConversationComposerState copyWith({
    String? draft,
    ConversationComposerMode? mode,
    List<ComposerAttachment>? attachments,
    Object? audioDraft = _sentinel,
    Object? savedDraftBeforeEdit = _sentinel,
    String? nextClientGeneratedId,
  }) {
    return ConversationComposerState(
      draft: draft ?? this.draft,
      mode: mode ?? this.mode,
      attachments: attachments ?? this.attachments,
      audioDraft: audioDraft == _sentinel
          ? this.audioDraft
          : audioDraft as ComposerAudioDraft?,
      savedDraftBeforeEdit: savedDraftBeforeEdit == _sentinel
          ? this.savedDraftBeforeEdit
          : savedDraftBeforeEdit as String?,
      nextClientGeneratedId:
          nextClientGeneratedId ?? this.nextClientGeneratedId,
    );
  }
}

class ConversationComposerViewModel
    extends Notifier<ConversationComposerState> {
  final ConversationTimelineV2Identity arg;

  ConversationComposerViewModel(this.arg);

  late final ConversationRepository _repository;
  late final ConversationTimelineV2Repository _timelineRepository;
  late final ConversationDraftStore _draftStore;
  late final AttachmentService _attachmentService;
  late final AttachmentPickerService _pickerService;
  late final AudioRecorderService _audioRecorderService;
  late final AudioWaveformCacheService _audioWaveformCacheService;
  late final ConversationLocalMutationRegistry _localMutationRegistry;
  late final ConversationScope _scope;
  Timer? _audioDurationTimer;
  DateTime? _audioRecordingStartedAt;
  bool _cancelPendingAudioStart = false;

  @override
  ConversationComposerState build() {
    _scope = arg.threadRootId == null
        ? ConversationScope.chat(chatId: arg.chatId)
        : ConversationScope.thread(
            chatId: arg.chatId,
            threadRootId: arg.threadRootId!,
          );
    _repository = ref.read(conversationRepositoryProvider(_scope));
    _timelineRepository = ref.read(
      conversationTimelineV2RepositoryProvider(arg),
    );
    _draftStore = ref.read(conversationDraftProvider);
    _attachmentService = ref.read(attachmentServiceProvider);
    _pickerService = ref.read(attachmentPickerServiceProvider);
    _audioRecorderService = ref.read(audioRecorderServiceProvider);
    _audioWaveformCacheService = ref.read(audioWaveformCacheServiceProvider);
    _localMutationRegistry = ref.read(
      conversationLocalMutationRegistryProvider,
    );
    ref.onDispose(() {
      _audioDurationTimer?.cancel();
      unawaited(_audioRecorderService.dispose());
    });
    final draft = _draftStore.getDraft(_scope) ?? '';
    return ConversationComposerState(
      draft: draft,
      mode: const ComposerIdle(),
      attachments: const <ComposerAttachment>[],
      audioDraft: null,
      savedDraftBeforeEdit: null,
      nextClientGeneratedId: _newClientGeneratedId(),
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
      audioDraft: null,
      savedDraftBeforeEdit: null,
    );
  }

  void beginEdit(ConversationMessage message) {
    final savedDraftBeforeEdit = state.isEditing
        ? state.savedDraftBeforeEdit
        : state.draft;
    state = state.copyWith(
      mode: ComposerEditing(message),
      draft: message.message ?? '',
      attachments: const <ComposerAttachment>[],
      audioDraft: null,
      savedDraftBeforeEdit: savedDraftBeforeEdit,
    );
  }

  void clearMode() {
    state = state.copyWith(
      mode: const ComposerIdle(),
      savedDraftBeforeEdit: null,
    );
  }

  Future<void> cancelEdit() async {
    final restoredDraft = state.savedDraftBeforeEdit ?? '';
    state = state.copyWith(
      draft: restoredDraft,
      mode: const ComposerIdle(),
      savedDraftBeforeEdit: null,
    );
    if (restoredDraft.trim().isEmpty) {
      await _draftStore.clearDraft(_scope);
      return;
    }
    await _draftStore.setDraft(_scope, restoredDraft);
  }

  Future<String?> pickAndQueueAttachments(
    ComposerAttachmentSource source,
  ) async {
    if (state.isEditing) {
      throw Exception('Editing messages does not support attachments');
    }
    if (state.audioDraft != null) {
      throw Exception('Clear the voice message draft before adding files.');
    }

    final remaining = state.remainingAttachmentSlots;
    if (remaining <= 0) {
      return 'You can attach up to '
          '${ConversationComposerState.maxAttachmentsPerMessage} files.';
    }

    final picked = await _pickerService.pick(source);
    if (picked.isEmpty) {
      return null;
    }

    final accepted = picked.take(remaining).map(_toDraftAttachment).toList();
    state = state.copyWith(attachments: [...state.attachments, ...accepted]);

    for (final attachment in accepted) {
      debugPrint('Uploading attachment ${attachment.localId}');
      unawaited(_uploadDraftAttachment(attachment.localId));
    }

    final skippedCount = picked.length - accepted.length;
    if (skippedCount > 0) {
      return 'You can attach up to '
          '${ConversationComposerState.maxAttachmentsPerMessage} files.';
    }
    return null;
  }

  void removeAttachment(String localId) {
    state = state.copyWith(
      attachments: state.attachments
          .where((item) => item.localId != localId)
          .toList(growable: false),
    );
  }

  void clearAttachments() {
    if (state.attachments.isEmpty) {
      return;
    }
    state = state.copyWith(attachments: const <ComposerAttachment>[]);
  }

  Future<void> retryAttachment(String localId) {
    final attachment = _attachmentByLocalId(localId);
    if (attachment == null) {
      return Future<void>.value();
    }
    return _uploadDraftAttachment(localId, forceRestart: true);
  }

  Future<void> send({required String text}) async {
    final trimmed = text.trim();
    final attachmentIds = state.uploadedAttachmentIds;
    final mode = state.mode;

    if (state.hasPendingAttachmentUploads) {
      throw Exception('Please wait for attachments to finish uploading.');
    }
    if (state.hasFailedAttachments) {
      throw Exception('Retry or remove failed attachments before sending.');
    }
    if (trimmed.isEmpty && attachmentIds.isEmpty) {
      return;
    }

    if (mode is ComposerEditing) {
      if (attachmentIds.isNotEmpty) {
        throw Exception('Editing messages does not support attachments');
      }
      final messageId = mode.message.serverMessageId!;
      final originalMessage = mode.message;
      final savedDraftBeforeEdit = state.savedDraftBeforeEdit;
      _repository.beginOptimisticEdit(messageId, trimmed);
      _dispatchLocalMutation(ConversationLocalMutationKind.updated);
      state = state.copyWith(
        draft: '',
        mode: const ComposerIdle(),
        attachments: const <ComposerAttachment>[],
        audioDraft: null,
        savedDraftBeforeEdit: null,
      );
      await _draftStore.clearDraft(_scope);
      unawaited(
        _commitEditInBackground(
          messageId: messageId,
          newText: trimmed,
          originalMessage: originalMessage,
          savedDraftBeforeEdit: savedDraftBeforeEdit,
        ),
      );
      return;
    }

    final optimisticAttachments = state.attachments
        .where((item) => item.isUploaded)
        .map((item) => item.toAttachmentItem())
        .toList(growable: false);

    final currentUserId = ref.read(authSessionProvider).currentUserId;
    await _sendMessage(
      _ComposerSendRequest(
        sender: Sender(uid: currentUserId, name: 'You'),
        text: trimmed,
        messageType: 'text',
        optimisticAttachments: optimisticAttachments,
        attachmentIds: attachmentIds,
        replyToId: mode is ComposerReplying
            ? mode.message.serverMessageId
            : null,
      ),
    );
  }

  Future<void> sendSticker(StickerSummary sticker) async {
    final stickerId = sticker.id;
    if (stickerId == null) return;
    final currentUserId = ref.read(authSessionProvider).currentUserId;
    final mode = state.mode;
    await _sendMessage(
      _ComposerSendRequest(
        sender: Sender(uid: currentUserId, name: 'You'),
        text: '',
        messageType: 'sticker',
        optimisticAttachments: const [],
        attachmentIds: const [],
        replyToId: mode is ComposerReplying
            ? mode.message.serverMessageId
            : null,
        sticker: sticker,
        stickerId: stickerId,
      ),
    );
  }

  /// Draft attachments move through queued -> uploading -> uploaded/failed.
  /// `localId` stays stable across retries until the backend returns an
  /// `attachmentId`, which is what gets included in the final message send.
  Future<void> _uploadDraftAttachment(
    String localId, {
    bool forceRestart = false,
  }) async {
    debugPrint('in upload attachment: $localId');
    final attachment = _attachmentByLocalId(localId);
    if (attachment == null) {
      debugPrint(
        'upload skipped because draft attachment was not found: $localId',
      );
      return;
    }
    if (attachment.isUploading) {
      debugPrint('upload skipped because draft is already uploading: $localId');
      return;
    }
    if (!forceRestart &&
        attachment.status == ComposerAttachmentUploadStatus.uploaded) {
      debugPrint('upload skipped because draft is already uploaded: $localId');
      return;
    }

    _updateAttachmentByLocalId(
      localId,
      (current) => current.copyWith(
        status: ComposerAttachmentUploadStatus.uploading,
        progress: 0,
        clearAttachmentId: true,
        clearErrorMessage: true,
      ),
    );

    final current = _attachmentByLocalId(localId);
    if (current == null) {
      debugPrint(
        'upload aborted because draft disappeared after status update: $localId',
      );
      return;
    }

    try {
      debugPrint('Requesting upload URL for ${current.name}');
      final uploadInfo = await _attachmentService.requestUploadUrl(
        filename: current.name,
        contentType: current.mimeType,
        size: current.sizeBytes,
        width: current.width,
        height: current.height,
      );
      debugPrint('Received upload URL for ${current.name}');
      debugPrint('Uploading file bytes for ${current.name}');
      await _attachmentService.uploadFileToS3(
        uploadUrl: uploadInfo.uploadUrl,
        file: current.file,
        uploadHeaders: uploadInfo.uploadHeaders,
        onProgress: (progress) {
          _updateAttachmentByLocalId(
            localId,
            (latest) => latest.copyWith(progress: progress),
          );
        },
      );
      debugPrint('Upload completed for ${current.name}');
      _updateAttachmentByLocalId(
        localId,
        (latest) => latest.copyWith(
          status: ComposerAttachmentUploadStatus.uploaded,
          progress: 1,
          attachmentId: uploadInfo.attachmentId,
          clearErrorMessage: true,
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Upload failed for $localId: $error');
      debugPrint('$stackTrace');
      _updateAttachmentByLocalId(
        localId,
        (latest) => latest.copyWith(
          status: ComposerAttachmentUploadStatus.failed,
          progress: 0,
          errorMessage: 'Upload failed',
          clearAttachmentId: true,
        ),
      );
    }
  }

  ComposerAttachment? _attachmentByLocalId(String localId) {
    for (final attachment in state.attachments) {
      if (attachment.localId == localId) {
        return attachment;
      }
    }
    return null;
  }

  void _updateAttachmentByLocalId(
    String localId,
    ComposerAttachment Function(ComposerAttachment current) update,
  ) {
    var found = false;
    final next = state.attachments
        .map((attachment) {
          if (attachment.localId != localId) {
            return attachment;
          }
          found = true;
          return update(attachment);
        })
        .toList(growable: false);
    if (!found) {
      debugPrint(
        'update skipped because draft attachment was not found: $localId',
      );
      return;
    }
    state = state.copyWith(attachments: next);
  }

  ComposerAttachment _toDraftAttachment(PickedComposerAttachment item) {
    return ComposerAttachment(
      localId: item.localId,
      file: item.file,
      name: item.name,
      mimeType: item.mimeType,
      kind: item.kind,
      sizeBytes: item.sizeBytes,
      previewBytes: item.previewBytes,
      width: item.width,
      height: item.height,
      progress: 0,
      status: ComposerAttachmentUploadStatus.queued,
    );
  }

  Future<void> startAudioRecording() async {
    if (!state.canStartAudio) {
      return;
    }

    _cancelPendingAudioStart = false;
    _audioDurationTimer?.cancel();
    state = state.copyWith(
      audioDraft: const ComposerAudioDraft(
        path: '',
        fileName: '',
        mimeType: 'audio/mp4',
        sizeBytes: 0,
        duration: Duration.zero,
        phase: ComposerAudioDraftPhase.requestingPermission,
      ),
    );

    try {
      final hasPermission = await _audioRecorderService.hasPermission();
      if (!hasPermission) {
        state = state.copyWith(audioDraft: null);
        throw const ComposerAudioException(
          ComposerAudioErrorCode.permissionDenied,
        );
      }

      await _audioRecorderService.start();
      if (_cancelPendingAudioStart) {
        _cancelPendingAudioStart = false;
        await _audioRecorderService.cancel();
        state = state.copyWith(audioDraft: null);
        return;
      }

      _audioRecordingStartedAt = DateTime.now();
      state = state.copyWith(
        audioDraft: state.audioDraft?.copyWith(
          phase: ComposerAudioDraftPhase.recording,
          duration: Duration.zero,
        ),
      );
      _audioDurationTimer = Timer.periodic(const Duration(milliseconds: 200), (
        _,
      ) {
        final startedAt = _audioRecordingStartedAt;
        final currentDraft = state.audioDraft;
        if (startedAt == null ||
            currentDraft == null ||
            currentDraft.phase != ComposerAudioDraftPhase.recording) {
          return;
        }
        state = state.copyWith(
          audioDraft: currentDraft.copyWith(
            duration: DateTime.now().difference(startedAt),
          ),
        );
      });
    } on UnsupportedError {
      state = state.copyWith(audioDraft: null);
      throw const ComposerAudioException(ComposerAudioErrorCode.unsupported);
    } on ComposerAudioException {
      rethrow;
    } catch (_) {
      state = state.copyWith(audioDraft: null);
      throw const ComposerAudioException(ComposerAudioErrorCode.startFailed);
    }
  }

  Future<void> finishAudioRecording() async {
    final currentDraft = state.audioDraft;
    if (currentDraft == null) {
      return;
    }

    if (currentDraft.phase == ComposerAudioDraftPhase.requestingPermission) {
      _cancelPendingAudioStart = true;
      state = state.copyWith(audioDraft: null);
      return;
    }
    if (currentDraft.phase != ComposerAudioDraftPhase.recording) {
      return;
    }

    _audioDurationTimer?.cancel();
    final duration = _currentAudioDuration();

    try {
      final recorded = await _audioRecorderService.stop(duration: duration);
      _audioRecordingStartedAt = null;
      if (recorded == null) {
        state = state.copyWith(audioDraft: null);
        return;
      }
      if (recorded.duration < composerMinAudioDuration) {
        state = state.copyWith(audioDraft: null);
        await _deleteFileIfExists(recorded.path);
        throw const ComposerAudioException(ComposerAudioErrorCode.tooShort);
      }

      state = state.copyWith(
        audioDraft: ComposerAudioDraft(
          path: recorded.path,
          fileName: recorded.fileName,
          mimeType: recorded.mimeType,
          sizeBytes: recorded.sizeBytes,
          duration: recorded.duration,
          phase: ComposerAudioDraftPhase.recorded,
          waveformSamples:
              (await _audioWaveformCacheService.primeFromLocalRecording(
                attachmentId: recorded.fileName,
                audioFilePath: recorded.path,
                duration: recorded.duration,
              ))?.samples ??
              const <int>[],
        ),
      );
    } on ComposerAudioException {
      rethrow;
    } catch (_) {
      state = state.copyWith(audioDraft: null);
      throw const ComposerAudioException(ComposerAudioErrorCode.startFailed);
    }
  }

  Future<void> cancelAudioRecording() async {
    final currentDraft = state.audioDraft;
    if (currentDraft == null) {
      return;
    }

    _audioDurationTimer?.cancel();
    _audioRecordingStartedAt = null;

    if (currentDraft.phase == ComposerAudioDraftPhase.requestingPermission) {
      _cancelPendingAudioStart = true;
      state = state.copyWith(audioDraft: null);
      return;
    }

    if (currentDraft.phase == ComposerAudioDraftPhase.recording) {
      final isRecording = await _audioRecorderService.isRecording();
      if (isRecording) {
        await _audioRecorderService.cancel();
      }
    }

    state = state.copyWith(audioDraft: null);
    await _deleteFileIfExists(currentDraft.path);
  }

  Future<void> sendRecordedAudio() async {
    final audioDraft = state.audioDraft;
    if (audioDraft == null ||
        audioDraft.phase != ComposerAudioDraftPhase.recorded) {
      return;
    }

    state = state.copyWith(
      audioDraft: audioDraft.copyWith(
        phase: ComposerAudioDraftPhase.uploading,
        progress: 0,
      ),
    );

    // On iOS/macOS, convert M4A recording to OGG/Opus before upload.
    final ComposerAudioDraft uploadDraft;
    String? oggPath;
    if (Platform.isIOS || Platform.isMacOS) {
      oggPath = audioDraft.path.replaceAll(RegExp(r'\.m4a$'), '.ogg');
      try {
        await VoiceMessage.convertM4aToOgg(
          srcPath: audioDraft.path,
          destPath: oggPath,
        );
      } catch (_) {
        state = state.copyWith(
          audioDraft: audioDraft.copyWith(
            phase: ComposerAudioDraftPhase.recorded,
            progress: 0,
          ),
        );
        throw const ComposerAudioException(ComposerAudioErrorCode.uploadFailed);
      }
      final oggFile = File(oggPath);
      final oggStat = await oggFile.stat();
      final oggFileName = audioDraft.fileName.replaceAll(
        RegExp(r'\.m4a$'),
        '.ogg',
      );
      uploadDraft = audioDraft.copyWith(
        path: oggPath,
        fileName: oggFileName,
        mimeType: 'audio/ogg',
        sizeBytes: oggStat.size,
      );
    } else {
      uploadDraft = audioDraft;
    }

    final platformFile = PlatformFile(
      name: uploadDraft.fileName,
      size: uploadDraft.sizeBytes,
      path: uploadDraft.path,
      readStream: File(uploadDraft.path).openRead(),
    );

    late final UploadUrlResponse uploadInfo;
    try {
      uploadInfo = await _attachmentService.requestUploadUrl(
        filename: uploadDraft.fileName,
        contentType: uploadDraft.mimeType,
        size: uploadDraft.sizeBytes,
      );
      await _attachmentService.uploadFileToS3(
        uploadUrl: uploadInfo.uploadUrl,
        file: platformFile,
        uploadHeaders: uploadInfo.uploadHeaders,
        onProgress: (progress) {
          final latest = state.audioDraft;
          if (latest == null ||
              latest.phase != ComposerAudioDraftPhase.uploading) {
            return;
          }
          state = state.copyWith(
            audioDraft: latest.copyWith(progress: progress),
          );
        },
      );
    } catch (_) {
      state = state.copyWith(
        audioDraft: audioDraft.copyWith(
          phase: ComposerAudioDraftPhase.recorded,
          progress: 0,
        ),
      );
      throw const ComposerAudioException(ComposerAudioErrorCode.uploadFailed);
    } finally {
      if (oggPath != null) {
        _deleteFileIfExists(oggPath);
      }
    }

    final currentUserId = ref.read(authSessionProvider).currentUserId;
    final mode = state.mode;
    await ref
        .read(audioWaveformCacheServiceProvider)
        .primeFromAttachmentMetadata(
          attachmentId: uploadInfo.attachmentId,
          duration: uploadDraft.duration,
          samples: uploadDraft.waveformSamples,
        );
    await _sendMessage(
      _ComposerSendRequest(
        sender: Sender(uid: currentUserId, name: 'You'),
        text: '',
        messageType: 'audio',
        optimisticAttachments: [
          uploadDraft.toAttachmentItem(attachmentId: uploadInfo.attachmentId),
        ],
        attachmentIds: [uploadInfo.attachmentId],
        replyToId: mode is ComposerReplying
            ? mode.message.serverMessageId
            : null,
      ),
    );
  }

  /// Perform the core message sending. Realistically it is optimistic send
  Future<void> _sendMessage(_ComposerSendRequest request) async {
    final clientGeneratedId = _consumeNextClientGeneratedId();
    final optimisticMessage = ConversationMessageV2(
      clientGeneratedId: clientGeneratedId,
      sender: request.sender,
      createdAt: DateTime.now(),
      replyToMessage: _replyToMessageForMode(state.mode),
      deliveryState: ConversationDeliveryState.sending,
      content: _optimisticContent(request),
    );
    final sendFuture = _timelineRepository.sendMessage(
      optimisticMessage: optimisticMessage,
      attachmentIds: request.attachmentIds,
    );
    state = state.copyWith(
      draft: '',
      mode: const ComposerIdle(),
      attachments: const <ComposerAttachment>[],
      audioDraft: null,
      savedDraftBeforeEdit: null,
    );
    await _draftStore.clearDraft(_scope);
    await sendFuture;
  }

  MessageContent _optimisticContent(_ComposerSendRequest request) {
    if (request.messageType == 'sticker') {
      return StickerMessageContent(sticker: request.sticker!);
    }
    if (request.messageType == 'audio') {
      return AudioMessageContent(
        audio: request.optimisticAttachments.single,
        text: request.text,
      );
    }
    if (request.optimisticAttachments.isNotEmpty) {
      return FileMessageContent(
        text: request.text,
        attachments: request.optimisticAttachments,
      );
    }
    return TextMessageContent(text: request.text);
  }

  ReplyToMessage? _replyToMessageForMode(ConversationComposerMode mode) {
    if (mode case ComposerReplying(:final message)) {
      final serverMessageId = message.serverMessageId;
      if (serverMessageId == null) {
        return null;
      }
      return ReplyToMessage(
        id: serverMessageId,
        message: message.message,
        messageType: message.messageType,
        sticker: message.sticker,
        sender: message.sender,
        isDeleted: message.isDeleted,
        attachments: message.attachments,
        reactions: message.reactions,
        firstAttachmentKind: message.attachments.isEmpty
            ? null
            : message.attachments.first.kind,
        mentions: message.mentions,
      );
    }
    return null;
  }

  Future<void> _commitEditInBackground({
    required int messageId,
    required String newText,
    required ConversationMessage originalMessage,
    required String? savedDraftBeforeEdit,
  }) async {
    try {
      await _repository.commitEdit(messageId, newText);
      _dispatchLocalMutation(ConversationLocalMutationKind.updated);
    } catch (error, stackTrace) {
      developer.log(
        'edit commit failed for messageId=$messageId',
        name: 'ComposerVM',
        error: error,
        stackTrace: stackTrace,
      );
      _repository.rollbackEdit(messageId);
      _dispatchLocalMutation(ConversationLocalMutationKind.updated);
      state = state.copyWith(
        draft: newText,
        mode: ComposerEditing(originalMessage),
        attachments: const <ComposerAttachment>[],
        audioDraft: null,
        savedDraftBeforeEdit: savedDraftBeforeEdit,
      );
      if (newText.trim().isEmpty) {
        await _draftStore.clearDraft(_scope);
      } else {
        await _draftStore.setDraft(_scope, newText);
      }
    }
  }

  String _newClientGeneratedId() {
    final currentUserId = ref.read(authSessionProvider).currentUserId;
    return '${DateTime.now().microsecondsSinceEpoch}-$currentUserId-${_scope.storageKey}';
  }

  String _consumeNextClientGeneratedId() {
    final current = state.nextClientGeneratedId.isNotEmpty
        ? state.nextClientGeneratedId
        : _newClientGeneratedId();
    state = state.copyWith(nextClientGeneratedId: _newClientGeneratedId());
    return current;
  }

  Duration _currentAudioDuration() {
    final startedAt = _audioRecordingStartedAt;
    if (startedAt == null) {
      return state.audioDraft?.duration ?? Duration.zero;
    }
    return DateTime.now().difference(startedAt);
  }

  Future<void> _deleteFileIfExists(String path) async {
    if (path.isEmpty) {
      return;
    }
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  void _dispatchLocalMutation(ConversationLocalMutationKind kind) {
    _localMutationRegistry.dispatch(
      ConversationLocalMutation(scope: _scope, kind: kind),
    );
  }
}

final attachmentServiceProvider = Provider<AttachmentService>((ref) {
  return AttachmentService(ref.watch(dioProvider));
});

final attachmentPickerServiceProvider = Provider<AttachmentPickerService>((
  ref,
) {
  return AttachmentPickerService();
});

final audioRecorderServiceProvider = Provider<AudioRecorderService>((ref) {
  return AudioRecorderService();
});

final conversationComposerViewModelProvider =
    NotifierProvider.family<
      ConversationComposerViewModel,
      ConversationComposerState,
      ConversationTimelineV2Identity
    >(ConversationComposerViewModel.new);

const _sentinel = Object();
