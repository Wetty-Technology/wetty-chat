import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:chahua/core/session/dev_session_store.dart';
import 'package:chahua/features/chats/conversation/application/conversation_composer_view_model.dart';
import 'package:chahua/features/chats/conversation/data/audio_recorder_service.dart';
import 'package:chahua/features/chats/conversation/data/audio_waveform_cache_service.dart';
import 'package:chahua/features/chats/conversation/data/conversation_repository.dart';
import 'package:chahua/features/chats/conversation/data/message_api_service.dart';
import 'package:chahua/features/chats/conversation/domain/conversation_message.dart';
import 'package:chahua/features/chats/conversation/domain/conversation_scope.dart';
import 'package:chahua/features/chats/message_domain/domain/message_domain.dart';
import 'package:chahua/features/chats/models/message_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConversationComposerViewModel edit cancel flow', () {
    test(
      'beginEdit snapshots the existing draft and replaces the draft',
      () async {
        final scope = _scope('begin-edit');
        final repository = _FakeConversationRepository(scope);
        final container = _createContainer(
          scope: scope,
          repository: repository,
        );
        addTearDown(container.dispose);
        final provider = conversationComposerViewModelProvider(scope);
        final notifier = container.read(provider.notifier);

        await notifier.updateDraft('draft before edit');
        notifier.beginEdit(
          _message(scope, id: 41, text: 'message being edited'),
        );

        final state = container.read(provider);
        expect(state.isEditing, isTrue);
        expect(state.draft, 'message being edited');
        expect(state.savedDraftBeforeEdit, 'draft before edit');
      },
    );

    test(
      'cancelEdit restores the pre-edit draft and returns to idle',
      () async {
        final scope = _scope('cancel-edit-restore');
        final repository = _FakeConversationRepository(scope);
        final container = _createContainer(
          scope: scope,
          repository: repository,
        );
        addTearDown(container.dispose);
        final provider = conversationComposerViewModelProvider(scope);
        final notifier = container.read(provider.notifier);

        await notifier.updateDraft('draft before edit');
        notifier.beginEdit(
          _message(scope, id: 42, text: 'message being edited'),
        );

        await notifier.cancelEdit();

        final state = container.read(provider);
        expect(state.mode, isA<ComposerIdle>());
        expect(state.draft, 'draft before edit');
        expect(state.savedDraftBeforeEdit, isNull);
      },
    );

    test('cancelEdit with no pre-edit draft restores an empty draft', () async {
      final scope = _scope('cancel-edit-empty');
      final repository = _FakeConversationRepository(scope);
      final container = _createContainer(scope: scope, repository: repository);
      addTearDown(container.dispose);
      final provider = conversationComposerViewModelProvider(scope);
      final notifier = container.read(provider.notifier);

      notifier.beginEdit(_message(scope, id: 43, text: 'message being edited'));

      await notifier.cancelEdit();

      final state = container.read(provider);
      expect(state.mode, isA<ComposerIdle>());
      expect(state.draft, isEmpty);
      expect(state.savedDraftBeforeEdit, isNull);
    });

    test('successful edit send clears the draft and saved snapshot', () async {
      final scope = _scope('send-edit');
      final repository = _FakeConversationRepository(scope);
      final container = _createContainer(scope: scope, repository: repository);
      addTearDown(container.dispose);
      final provider = conversationComposerViewModelProvider(scope);
      final notifier = container.read(provider.notifier);

      await notifier.updateDraft('draft before edit');
      notifier.beginEdit(_message(scope, id: 44, text: 'message being edited'));

      await notifier.send(text: 'edited message');
      await Future<void>.delayed(Duration.zero);

      final state = container.read(provider);
      expect(repository.beginEditMessageId, 44);
      expect(repository.beginEditText, 'edited message');
      expect(repository.lastEditedMessageId, 44);
      expect(repository.lastEditedText, 'edited message');
      expect(state.mode, isA<ComposerIdle>());
      expect(state.draft, isEmpty);
      expect(state.savedDraftBeforeEdit, isNull);
    });
  });
}

ProviderContainer _createContainer({
  required ConversationScope scope,
  required _FakeConversationRepository repository,
}) {
  return ProviderContainer(
    overrides: [
      authSessionProvider.overrideWith(_AuthenticatedSessionNotifier.new),
      audioRecorderServiceProvider.overrideWithValue(
        _FakeAudioRecorderService(),
      ),
      audioWaveformCacheServiceProvider.overrideWithValue(
        _FakeAudioWaveformCacheService(),
      ),
      conversationRepositoryProvider(scope).overrideWithValue(repository),
    ],
  );
}

ConversationScope _scope(String id) =>
    ConversationScope.chat(chatId: 'chat-$id');

ConversationMessage _message(
  ConversationScope scope, {
  required int id,
  required String text,
}) {
  return ConversationMessage(
    scope: scope,
    serverMessageId: id,
    clientGeneratedId: 'client-$id',
    sender: const Sender(uid: 1, name: 'You'),
    message: text,
  );
}

class _AuthenticatedSessionNotifier extends AuthSessionNotifier {
  @override
  AuthSessionState build() {
    return const AuthSessionState(
      status: AuthBootstrapStatus.authenticated,
      mode: AuthSessionMode.devHeader,
      developerUserId: 1,
      currentUserId: 1,
    );
  }
}

class _FakeConversationRepository extends ConversationRepository {
  _FakeConversationRepository(ConversationScope scope)
    : super(
        scope: scope,
        service: _FakeMessageApiService(),
        store: MessageDomainStore(),
      );

  int? beginEditMessageId;
  String? beginEditText;
  int? lastEditedMessageId;
  String? lastEditedText;

  @override
  ConversationMessage? beginOptimisticEdit(int messageId, String newText) {
    beginEditMessageId = messageId;
    beginEditText = newText;
    return null;
  }

  @override
  Future<ConversationMessage> commitEdit(int messageId, String newText) async {
    lastEditedMessageId = messageId;
    lastEditedText = newText;
    return ConversationMessage(
      scope: scope,
      serverMessageId: messageId,
      clientGeneratedId: 'edited-$messageId',
      sender: const Sender(uid: 1, name: 'You'),
      message: newText,
    );
  }
}

class _FakeMessageApiService extends MessageApiService {
  _FakeMessageApiService() : super(Dio(), 1);
}

class _FakeAudioRecorderService implements AudioRecorderService {
  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<bool> isRecording() async => false;

  @override
  Future<void> start() async {}

  @override
  Future<RecordedAudioFile?> stop({required Duration duration}) async => null;
}

class _FakeAudioWaveformCacheService implements AudioWaveformCacheService {
  @override
  void clearMemory() {}

  @override
  Future<AudioWaveformSnapshot?> primeFromAttachmentMetadata({
    required String attachmentId,
    required Duration duration,
    required List<int> samples,
  }) async => null;

  @override
  Future<AudioWaveformSnapshot?> primeFromLocalRecording({
    required String attachmentId,
    required String audioFilePath,
    required Duration duration,
  }) async => null;

  @override
  Future<AudioWaveformSnapshot?> resolveForAttachment(
    AttachmentItem attachment, {
    Duration? preferredDuration,
    String? waveformInputPath,
  }) async => null;
}
