import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

enum AudioPlaybackDriverPhase { idle, loading, buffering, ready, completed }

class AudioPlaybackStatus {
  const AudioPlaybackStatus({
    required this.phase,
    required this.isPlaying,
    required this.position,
    required this.bufferedPosition,
    this.duration,
  });

  final AudioPlaybackDriverPhase phase;
  final bool isPlaying;
  final Duration position;
  final Duration bufferedPosition;
  final Duration? duration;
}

abstract class AudioPlaybackDriver {
  Stream<AudioPlaybackStatus> get statusStream;
  AudioPlaybackStatus get currentStatus;

  Future<Duration?> setSourceUrl(String url);
  Future<Duration?> setSourceFilePath(String path);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> stop();
  Future<void> dispose();
}

class JustAudioPlaybackDriver implements AudioPlaybackDriver {
  JustAudioPlaybackDriver({AudioPlayer? player})
    : _player = player ?? AudioPlayer() {
    _subscriptions = <StreamSubscription<dynamic>>[
      _player.playerStateStream.listen((_) => _emitStatus()),
      _player.playbackEventStream.listen((_) => _emitStatus()),
      _player.durationStream.listen((_) => _emitStatus()),
      _player.positionStream.listen((_) => _emitStatus()),
    ];
    _emitStatus();
  }

  final AudioPlayer _player;
  late final List<StreamSubscription<dynamic>> _subscriptions;
  final StreamController<AudioPlaybackStatus> _statusController =
      StreamController<AudioPlaybackStatus>.broadcast();

  @override
  Stream<AudioPlaybackStatus> get statusStream => _statusController.stream;

  @override
  AudioPlaybackStatus get currentStatus => _buildStatus();

  @override
  Future<Duration?> setSourceUrl(String url) async {
    final duration = await _player.setUrl(url);
    _emitStatus();
    return duration;
  }

  @override
  Future<Duration?> setSourceFilePath(String path) async {
    final duration = await _player.setFilePath(path);
    _emitStatus();
    return duration;
  }

  @override
  Future<void> play() async {
    await _player.play();
    _emitStatus();
  }

  @override
  Future<void> pause() async {
    await _player.pause();
    _emitStatus();
  }

  @override
  Future<void> seek(Duration position) async {
    await _player.seek(position);
    _emitStatus();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    _emitStatus();
  }

  @override
  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _statusController.close();
    await _player.dispose();
  }

  void _emitStatus() {
    if (_statusController.isClosed) {
      return;
    }
    _statusController.add(_buildStatus());
  }

  AudioPlaybackStatus _buildStatus() {
    final playerState = _player.playerState;
    final phase = switch (playerState.processingState) {
      ProcessingState.idle => AudioPlaybackDriverPhase.idle,
      ProcessingState.loading => AudioPlaybackDriverPhase.loading,
      ProcessingState.buffering => AudioPlaybackDriverPhase.buffering,
      ProcessingState.ready => AudioPlaybackDriverPhase.ready,
      ProcessingState.completed => AudioPlaybackDriverPhase.completed,
    };
    return AudioPlaybackStatus(
      phase: phase,
      isPlaying: playerState.playing,
      position: _player.position,
      bufferedPosition: _player.bufferedPosition,
      duration: _player.duration,
    );
  }
}

final audioPlaybackDriverProvider = Provider<AudioPlaybackDriver>((ref) {
  final driver = JustAudioPlaybackDriver();
  ref.onDispose(() {
    unawaited(driver.dispose());
  });
  return driver;
}, isAutoDispose: true);
