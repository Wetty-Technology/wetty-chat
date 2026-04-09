import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class RecordedAudioFile {
  const RecordedAudioFile({
    required this.path,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.duration,
  });

  final String path;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final Duration duration;
}

class AudioRecorderService {
  AudioRecorderService({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  static const String _mimeType = 'audio/mp4';
  final AudioRecorder _recorder;

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<void> start() async {
    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'voice-$timestamp.m4a';
    final path = '${directory.path}/$fileName';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );
  }

  Future<bool> isRecording() => _recorder.isRecording();

  Future<RecordedAudioFile?> stop({required Duration duration}) async {
    final path = await _recorder.stop();
    if (path == null || path.isEmpty) {
      return null;
    }

    final file = File(path);
    final stat = await file.stat();
    return RecordedAudioFile(
      path: path,
      fileName: file.uri.pathSegments.isEmpty
          ? 'voice-${DateTime.now().millisecondsSinceEpoch}.m4a'
          : file.uri.pathSegments.last,
      mimeType: _mimeType,
      sizeBytes: stat.size,
      duration: duration,
    );
  }

  Future<void> cancel() async {
    await _recorder.cancel();
  }

  Future<void> dispose() => _recorder.dispose();
}
