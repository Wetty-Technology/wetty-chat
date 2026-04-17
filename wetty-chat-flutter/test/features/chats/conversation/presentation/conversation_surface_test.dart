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
import 'package:chahua/features/chats/conversation/application/conversation_timeline_view_model.dart';
import 'package:chahua/features/chats/conversation/data/audio_recorder_service.dart';
import 'package:chahua/features/chats/conversation/data/audio_waveform_cache_service.dart';
import 'package:chahua/features/chats/conversation/data/message_api_service.dart';
import 'package:chahua/features/chats/conversation/domain/conversation_message.dart';
import 'package:chahua/features/chats/conversation/domain/conversation_scope.dart';
import 'package:chahua/features/chats/conversation/domain/launch_request.dart';
import 'package:chahua/features/chats/conversation/domain/timeline_entry.dart';
import 'package:chahua/features/chats/conversation/presentation/conversation_surface.dart';
import 'package:chahua/features/chats/conversation/presentation/timeline/conversation_timeline.dart';
import 'package:chahua/features/chats/models/message_models.dart';
import 'package:chahua/features/stickers/data/sticker_api_service.dart';
import 'package:chahua/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'latestVisibleMessageForViewport returns the newest visible message',
    () {
      const scope = ConversationScope.chat(chatId: '1');
      final first = _message(scope, id: 1, text: 'first');
      final second = _message(scope, id: 2, text: 'second');
      final third = _message(scope, id: 3, text: 'third');

      final latest = latestVisibleMessageForViewport(
        entries: <TimelineEntry>[
          TimelineMessageEntry(first),
          TimelineMessageEntry(second),
          TimelineMessageEntry(third),
        ],
        viewportRect: const Rect.fromLTWH(0, 0, 100, 100),
        resolveMessageRect: (stableKey) => switch (stableKey) {
          'server:1' => const Rect.fromLTWH(0, 0, 100, 20),
          'server:2' => const Rect.fromLTWH(0, 24, 100, 20),
          'server:3' => const Rect.fromLTWH(0, 120, 100, 20),
          _ => null,
        },
      );

      expect(latest?.serverMessageId, 2);
    },
  );

  testWidgets('surface opens picker, sends sticker, and closes picker', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final environment = await _createEnvironment();
    addTearDown(environment.container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: environment.container,
        child: _buildApp(
          child: ConversationSurface(
            scope: const ConversationScope.chat(chatId: '1'),
            timelineArgs: (
              scope: const ConversationScope.chat(chatId: '1'),
              launchRequest: const LaunchRequest.latest(),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(CupertinoIcons.smiley));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('picker-sticker-favorite-1')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('picker-sticker-favorite-1')));
    await tester.pumpAndSettle();

    expect(environment.messageService.lastSentStickerId, 'favorite-1');
    expect(
      find.byKey(const ValueKey('picker-sticker-favorite-1')),
      findsNothing,
    );
  });

  testWidgets('surface returns to latest after send while launched anchored', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final environment = await _createEnvironment(messageCount: 160);
    addTearDown(environment.container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: environment.container,
        child: _buildApp(
          child: ConversationSurface(
            scope: const ConversationScope.chat(chatId: '1'),
            timelineArgs: (
              scope: const ConversationScope.chat(chatId: '1'),
              launchRequest: const LaunchRequest.message(
                messageId: 10,
                highlight: false,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final before = environment.container.read(
      conversationTimelineViewModelProvider((
        scope: const ConversationScope.chat(chatId: '1'),
        launchRequest: const LaunchRequest.message(
          messageId: 10,
          highlight: false,
        ),
      )),
    );
    expect(before.value, isNotNull);
    expect(before.value!.windowMode, ConversationWindowMode.anchoredTarget);

    await tester.tap(find.byIcon(CupertinoIcons.smiley));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('picker-sticker-favorite-1')));
    await tester.pumpAndSettle();

    final after = environment.container.read(
      conversationTimelineViewModelProvider((
        scope: const ConversationScope.chat(chatId: '1'),
        launchRequest: const LaunchRequest.message(
          messageId: 10,
          highlight: false,
        ),
      )),
    );
    expect(after.value, isNotNull);
    expect(after.value!.windowMode, ConversationWindowMode.liveLatest);
    expect(after.value!.anchorMessageId, isNull);
    expect(after.value!.windowStableKeys.last, 'server:161');
  });

  testWidgets('surface does not re-emit latest visible message unchanged', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final environment = await _createEnvironment(messageCount: 16);
    addTearDown(environment.container.dispose);
    final visibleIds = <int>[];

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: environment.container,
        child: _buildApp(
          child: ConversationSurface(
            scope: const ConversationScope.chat(chatId: '1'),
            timelineArgs: (
              scope: const ConversationScope.chat(chatId: '1'),
              launchRequest: const LaunchRequest.latest(),
            ),
            onLatestVisibleMessageChanged: (message) {
              final id = message.serverMessageId;
              if (id != null) {
                visibleIds.add(id);
              }
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final countAfterInitialLayout = visibleIds.length;
    expect(countAfterInitialLayout, greaterThan(0));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));

    expect(visibleIds.length, countAfterInitialLayout);
  });
}

CupertinoApp _buildApp({required Widget child}) {
  return CupertinoApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: CupertinoPageScaffold(child: child),
  );
}

Future<_TestEnvironment> _createEnvironment({int messageCount = 8}) async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  final preferences = await SharedPreferences.getInstance();
  final messageService = _FakeMessageApiService(_buildMessages(messageCount));
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
    ],
  );
  return _TestEnvironment(container: container, messageService: messageService);
}

List<MessageItemDto> _buildMessages(int count) {
  const sender = SenderDto(uid: 7, name: 'Tester');
  return List<MessageItemDto>.generate(count, (index) {
    final id = index + 1;
    return MessageItemDto(
      id: id,
      message: 'Message $id',
      sender: sender,
      chatId: 1,
      createdAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: id)),
      clientGeneratedId: 'cg-$id',
    );
  });
}

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

class _TestEnvironment {
  const _TestEnvironment({
    required this.container,
    required this.messageService,
  });

  final ProviderContainer container;
  final _FakeMessageApiService messageService;
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

class _FakeMessageApiService extends MessageApiService {
  _FakeMessageApiService(this._messages) : super(Dio(), 1);

  final List<MessageItemDto> _messages;
  String? lastSentStickerId;

  @override
  Future<ListMessagesResponseDto> fetchConversationMessages(
    ConversationScope scope, {
    int? max,
    int? before,
    int? after,
    int? around,
  }) async {
    if (around != null) {
      final index = _messages.indexWhere((message) => message.id == around);
      if (index < 0) {
        return const ListMessagesResponseDto();
      }
      final limit = max ?? _messages.length;
      final beforeCount = (limit - 1) ~/ 2;
      final afterCount = limit - beforeCount - 1;
      final end = (index + afterCount + 1).clamp(0, _messages.length);
      final adjustedStart = (end - limit).clamp(0, _messages.length);
      return ListMessagesResponseDto(
        messages: _messages.sublist(adjustedStart, end),
      );
    }
    if (before != null) {
      final filtered = _messages
          .where((message) => message.id < before)
          .toList(growable: false);
      if (max == null || filtered.length <= max) {
        return ListMessagesResponseDto(messages: filtered);
      }
      return ListMessagesResponseDto(
        messages: filtered.sublist(filtered.length - max),
      );
    }
    if (after != null) {
      final filtered = _messages
          .where((message) => message.id > after)
          .toList(growable: false);
      if (max == null || filtered.length <= max) {
        return ListMessagesResponseDto(messages: filtered);
      }
      return ListMessagesResponseDto(messages: filtered.sublist(0, max));
    }
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
    lastSentStickerId = stickerId;
    final nextId = _messages.length + 1;
    final sent = MessageItemDto(
      id: nextId,
      message: text,
      messageType: messageType,
      sender: const SenderDto(uid: 1, name: 'You'),
      chatId: int.parse(scope.chatId),
      createdAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: nextId)),
      clientGeneratedId: clientGeneratedId,
      replyRootId: replyToId,
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
          id: 'favorite-1',
          emoji: '😀',
          media: StickerMediaDto(id: 'media-favorite-1', url: ''),
        ),
      ],
    );
  }

  @override
  Future<void> saveStickerPackOrder(List<dynamic> order) async {}
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
