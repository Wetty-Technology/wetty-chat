import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chahua/core/api/models/chats_api_models.dart';
import 'package:chahua/core/api/models/messages_api_models.dart';
import 'package:chahua/core/api/models/stickers_api_models.dart';
import 'package:chahua/core/providers/shared_preferences_provider.dart';
import 'package:chahua/core/session/dev_session_store.dart';
import 'package:chahua/features/chats/conversation/application/conversation_composer_view_model.dart';
import 'package:chahua/features/chats/conversation/data/audio_recorder_service.dart';
import 'package:chahua/features/chats/conversation/data/audio_waveform_cache_service.dart';
import 'package:chahua/features/chats/conversation/data/message_api_service.dart';
import 'package:chahua/features/chats/conversation/domain/conversation_scope.dart';
import 'package:chahua/features/chats/conversation/presentation/thread_detail_view.dart';
import 'package:chahua/features/chats/models/message_models.dart';
import 'package:chahua/features/chats/threads/data/thread_api_service.dart';
import 'package:chahua/features/chats/threads/models/thread_api_models.dart';
import 'package:chahua/features/groups/metadata/data/group_metadata_api_service.dart';
import 'package:chahua/features/groups/metadata/data/group_metadata_models.dart';
import 'package:chahua/features/groups/metadata/data/group_metadata_repository.dart';
import 'package:chahua/features/stickers/data/sticker_api_service.dart';
import 'package:chahua/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('thread detail opens sticker picker and sends thread sticker', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues(const <String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final messageService = _FakeThreadMessageApiService(_buildMessages());
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        authSessionProvider.overrideWith(_AuthenticatedSessionNotifier.new),
        audioRecorderServiceProvider.overrideWithValue(
          _FakeAudioRecorderService(),
        ),
        audioWaveformCacheServiceProvider.overrideWithValue(
          _FakeAudioWaveformCacheService(),
        ),
        messageApiServiceProvider.overrideWithValue(messageService),
        stickerApiServiceProvider.overrideWithValue(_FakeStickerApiService()),
        threadApiServiceProvider.overrideWithValue(_FakeThreadApiService()),
        groupMetadataRepositoryProvider.overrideWithValue(
          _FakeGroupMetadataRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: CupertinoApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ThreadDetailPage(chatId: '1', threadRootId: '42'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(CupertinoIcons.smiley));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('picker-sticker-thread-favorite')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('picker-sticker-thread-favorite')),
    );
    await tester.pumpAndSettle();

    expect(messageService.lastSentScope, isNotNull);
    expect(messageService.lastSentScope!.isThread, isTrue);
    expect(messageService.lastSentScope!.threadRootId, '42');
    expect(messageService.lastSentStickerId, 'thread-favorite');
  });
}

List<MessageItemDto> _buildMessages() {
  const sender = SenderDto(uid: 7, name: 'Tester');
  return List<MessageItemDto>.generate(10, (index) {
    final id = index + 1;
    return MessageItemDto(
      id: id,
      message: 'Thread message $id',
      sender: sender,
      chatId: 1,
      replyRootId: 42,
      createdAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: id)),
      clientGeneratedId: 'cg-$id',
    );
  });
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

class _FakeThreadMessageApiService extends MessageApiService {
  _FakeThreadMessageApiService(this._messages) : super(Dio(), 1);

  final List<MessageItemDto> _messages;
  ConversationScope? lastSentScope;
  String? lastSentStickerId;

  @override
  Future<ListMessagesResponseDto> fetchConversationMessages(
    ConversationScope scope, {
    int? max,
    int? before,
    int? after,
    int? around,
  }) async {
    if (max == null || _messages.length <= max) {
      return ListMessagesResponseDto(messages: _messages);
    }
    return ListMessagesResponseDto(
      messages: _messages.sublist(_messages.length - max),
    );
  }

  @override
  Future<MessageItemDto> sendConversationMessage(
    ConversationScope scope,
    String text, {
    required String messageType,
    int? replyToId,
    List<String> attachmentIds = const <String>[],
    required String clientGeneratedId,
    String? stickerId,
  }) async {
    lastSentScope = scope;
    lastSentStickerId = stickerId;
    final nextId = _messages.length + 1;
    final sent = MessageItemDto(
      id: nextId,
      message: text,
      messageType: messageType,
      sender: const SenderDto(uid: 1, name: 'You'),
      chatId: int.parse(scope.chatId),
      replyRootId: int.tryParse(scope.threadRootId ?? ''),
      createdAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: nextId)),
      clientGeneratedId: clientGeneratedId,
      sticker: stickerId == null
          ? null
          : StickerSummaryDto(
              id: stickerId,
              emoji: '😀',
              media: StickerMediaDto(id: 'media-$stickerId', url: ''),
            ),
    );
    _messages.add(sent);
    return sent;
  }

  @override
  Future<MarkChatReadStateResponseDto> markMessagesAsRead(
    String chatId,
    int messageId,
  ) async {
    return const MarkChatReadStateResponseDto();
  }
}

class _FakeStickerApiService extends StickerApiService {
  _FakeStickerApiService() : super(Dio());

  @override
  Future<StickerPackListResponseDto> fetchOwnedPacks() async {
    return const StickerPackListResponseDto();
  }

  @override
  Future<StickerPackListResponseDto> fetchSubscribedPacks() async {
    return const StickerPackListResponseDto();
  }

  @override
  Future<FavoriteStickerListResponseDto> fetchFavorites() async {
    return FavoriteStickerListResponseDto(
      stickers: <StickerSummaryDto>[
        StickerSummaryDto(
          id: 'thread-favorite',
          emoji: '🧵',
          media: StickerMediaDto(id: 'media-thread-favorite', url: ''),
        ),
      ],
    );
  }

  @override
  Future<void> saveStickerPackOrder(List<dynamic> order) async {}
}

class _FakeThreadApiService extends ThreadApiService {
  _FakeThreadApiService() : super(Dio());

  @override
  Future<bool> getThreadSubscriptionStatus(
    String chatId,
    int threadRootId,
  ) async => false;

  @override
  Future<MarkThreadReadResponseDto> markThreadAsRead(
    int threadRootId,
    int messageId,
  ) async {
    return const MarkThreadReadResponseDto(updated: true);
  }

  @override
  Future<UnreadThreadCountResponseDto> fetchUnreadThreadCount() async {
    return const UnreadThreadCountResponseDto();
  }

  @override
  Future<ListThreadsResponseDto> fetchThreads({
    int? limit,
    String? before,
  }) async {
    return const ListThreadsResponseDto();
  }
}

class _FakeGroupMetadataRepository extends GroupMetadataRepository {
  _FakeGroupMetadataRepository() : super(_FakeGroupMetadataApiService());

  @override
  Future<ChatMetadata> fetchMetadata(String chatId) async {
    return ChatMetadata(id: chatId, name: 'Thread Chat');
  }
}

class _FakeGroupMetadataApiService extends GroupMetadataApiService {
  _FakeGroupMetadataApiService() : super(Dio());
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
