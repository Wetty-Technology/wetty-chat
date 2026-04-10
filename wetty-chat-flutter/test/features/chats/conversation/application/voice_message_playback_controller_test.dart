import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:chahua/features/chats/conversation/application/voice_message_playback_controller.dart';
import 'package:chahua/features/chats/conversation/data/audio_playback_driver.dart';
import 'package:chahua/features/chats/models/message_models.dart';
import 'package:chahua/core/providers/shared_preferences_provider.dart';

void main() {
  group('VoiceMessagePlaybackController', () {
    test('first tap loads and starts playback', () async {
      final driver = FakeAudioPlaybackDriver();
      final container = await _createContainer(driver);
      addTearDown(container.dispose);

      final notifier = container.read(
        voiceMessagePlaybackControllerProvider.notifier,
      );
      await notifier.togglePlayback(
        _attachment(id: 'a1', url: 'https://example.com/a1.m4a'),
      );

      final state = container.read(voiceMessagePlaybackControllerProvider);
      expect(driver.loadedUrls, ['https://example.com/a1.m4a']);
      expect(driver.playCalls, 1);
      expect(state.activeAttachmentId, 'a1');
      expect(state.phase, VoiceMessagePlaybackPhase.playing);
      expect(state.durationFor('a1'), const Duration(seconds: 18));
    });

    test('tapping the active message toggles play and pause', () async {
      final driver = FakeAudioPlaybackDriver();
      final container = await _createContainer(driver);
      addTearDown(container.dispose);
      final attachment = _attachment(
        id: 'a1',
        url: 'https://example.com/a1.m4a',
      );
      final notifier = container.read(
        voiceMessagePlaybackControllerProvider.notifier,
      );

      await notifier.togglePlayback(attachment);
      await notifier.togglePlayback(attachment);

      expect(driver.pauseCalls, 1);
      expect(
        container.read(voiceMessagePlaybackControllerProvider).phase,
        VoiceMessagePlaybackPhase.paused,
      );

      await notifier.togglePlayback(attachment);

      expect(driver.playCalls, 2);
      expect(
        container.read(voiceMessagePlaybackControllerProvider).phase,
        VoiceMessagePlaybackPhase.playing,
      );
    });

    test('switching attachments activates the new message', () async {
      final driver = FakeAudioPlaybackDriver();
      final container = await _createContainer(driver);
      addTearDown(container.dispose);
      final notifier = container.read(
        voiceMessagePlaybackControllerProvider.notifier,
      );

      await notifier.togglePlayback(
        _attachment(id: 'a1', url: 'https://example.com/a1.m4a'),
      );
      await notifier.togglePlayback(
        _attachment(id: 'a2', url: 'https://example.com/a2.m4a'),
      );

      final state = container.read(voiceMessagePlaybackControllerProvider);
      expect(driver.loadedUrls, [
        'https://example.com/a1.m4a',
        'https://example.com/a2.m4a',
      ]);
      expect(state.activeAttachmentId, 'a2');
      expect(state.phase, VoiceMessagePlaybackPhase.playing);
    });

    test('seek updates the active position', () async {
      final driver = FakeAudioPlaybackDriver();
      final container = await _createContainer(driver);
      addTearDown(container.dispose);
      final notifier = container.read(
        voiceMessagePlaybackControllerProvider.notifier,
      );
      final attachment = _attachment(
        id: 'a1',
        url: 'https://example.com/a1.m4a',
      );

      await notifier.togglePlayback(attachment);
      await notifier.seekToAttachment(attachment, const Duration(seconds: 7));

      expect(driver.seekCalls, [const Duration(seconds: 7)]);
      expect(
        container.read(voiceMessagePlaybackControllerProvider).position,
        const Duration(seconds: 7),
      );
    });

    test('driver errors move state into error', () async {
      final driver = FakeAudioPlaybackDriver()..throwOnSetUrl = true;
      final container = await _createContainer(driver);
      addTearDown(container.dispose);

      final notifier = container.read(
        voiceMessagePlaybackControllerProvider.notifier,
      );
      await notifier.togglePlayback(
        _attachment(id: 'a1', url: 'https://example.com/a1.m4a'),
      );

      final state = container.read(voiceMessagePlaybackControllerProvider);
      expect(state.phase, VoiceMessagePlaybackPhase.error);
      expect(state.errorMessage, contains('load failed'));
    });
  });
}

Future<ProviderContainer> _createContainer(
  FakeAudioPlaybackDriver driver,
) async {
  SharedPreferences.setMockInitialValues(const <String, Object>{});
  final preferences = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      audioPlaybackDriverProvider.overrideWithValue(driver),
      sharedPreferencesProvider.overrideWithValue(preferences),
    ],
  );
}

AttachmentItem _attachment({required String id, required String url}) {
  return AttachmentItem(
    id: id,
    url: url,
    kind: 'audio/m4a',
    size: 128,
    fileName: 'voice.m4a',
  );
}

class FakeAudioPlaybackDriver implements AudioPlaybackDriver {
  final StreamController<AudioPlaybackStatus> _controller =
      StreamController<AudioPlaybackStatus>.broadcast();

  final List<String> loadedUrls = <String>[];
  final List<Duration> seekCalls = <Duration>[];

  int playCalls = 0;
  int pauseCalls = 0;
  bool throwOnSetUrl = false;
  AudioPlaybackStatus _status = const AudioPlaybackStatus(
    phase: AudioPlaybackDriverPhase.idle,
    isPlaying: false,
    position: Duration.zero,
    bufferedPosition: Duration.zero,
  );

  @override
  Stream<AudioPlaybackStatus> get statusStream => _controller.stream;

  @override
  AudioPlaybackStatus get currentStatus => _status;

  @override
  Future<Duration?> setSourceUrl(String url) async {
    if (throwOnSetUrl) {
      throw StateError('load failed');
    }
    loadedUrls.add(url);
    _status = const AudioPlaybackStatus(
      phase: AudioPlaybackDriverPhase.ready,
      isPlaying: false,
      position: Duration.zero,
      bufferedPosition: Duration.zero,
      duration: Duration(seconds: 18),
    );
    _controller.add(_status);
    return _status.duration;
  }

  @override
  Future<Duration?> setSourceFilePath(String path) async {
    return setSourceUrl(path);
  }

  @override
  Future<void> play() async {
    playCalls += 1;
    _status = AudioPlaybackStatus(
      phase: AudioPlaybackDriverPhase.ready,
      isPlaying: true,
      position: _status.position,
      bufferedPosition: _status.bufferedPosition,
      duration: _status.duration,
    );
    _controller.add(_status);
  }

  @override
  Future<void> pause() async {
    pauseCalls += 1;
    _status = AudioPlaybackStatus(
      phase: AudioPlaybackDriverPhase.ready,
      isPlaying: false,
      position: _status.position,
      bufferedPosition: _status.bufferedPosition,
      duration: _status.duration,
    );
    _controller.add(_status);
  }

  @override
  Future<void> seek(Duration position) async {
    seekCalls.add(position);
    _status = AudioPlaybackStatus(
      phase: AudioPlaybackDriverPhase.ready,
      isPlaying: _status.isPlaying,
      position: position,
      bufferedPosition: position,
      duration: _status.duration,
    );
    _controller.add(_status);
  }

  @override
  Future<void> stop() async {
    _status = const AudioPlaybackStatus(
      phase: AudioPlaybackDriverPhase.idle,
      isPlaying: false,
      position: Duration.zero,
      bufferedPosition: Duration.zero,
    );
    _controller.add(_status);
  }

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}
