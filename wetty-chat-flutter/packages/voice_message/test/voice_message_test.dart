import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_message/src/voice_message_method_channel.dart';
import 'package:voice_message/src/voice_message_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('default platform', () {
    test('uses method channel on iOS and macOS', () {
      expect(
        VoiceMessagePlatform.createDefaultPlatform(
          targetPlatform: TargetPlatform.iOS,
        ),
        isA<MethodChannelVoiceMessage>(),
      );
      expect(
        VoiceMessagePlatform.createDefaultPlatform(
          targetPlatform: TargetPlatform.macOS,
        ),
        isA<MethodChannelVoiceMessage>(),
      );
    });

    test('uses unsupported platform on Android and other targets', () {
      for (final target in <TargetPlatform>[
        TargetPlatform.android,
        TargetPlatform.fuchsia,
        TargetPlatform.linux,
        TargetPlatform.windows,
      ]) {
        expect(
          VoiceMessagePlatform.createDefaultPlatform(targetPlatform: target),
          isA<UnsupportedVoiceMessagePlatform>(),
        );
      }
      expect(
        VoiceMessagePlatform.createDefaultPlatform(
          targetPlatform: TargetPlatform.iOS,
          isWeb: true,
        ),
        isA<UnsupportedVoiceMessagePlatform>(),
      );
    });
  });

  group('unsupported platform', () {
    test('reports native capabilities as unavailable', () {
      final platform = UnsupportedVoiceMessagePlatform();

      expect(platform.capabilities.canConvertOggToM4a, isFalse);
      expect(platform.capabilities.canConvertM4aToOgg, isFalse);
      expect(platform.capabilities.canExtractWaveform, isFalse);
      expect(platform.capabilities.canPreparePlayback, isTrue);
    });

    test(
      'passes playback files through and fails native operations clearly',
      () async {
        final platform = UnsupportedVoiceMessagePlatform();

        expect(
          platform.playbackPreparationFor(
            contentType: 'audio/ogg',
            fileName: 'voice.ogg',
          ),
          VoiceMessagePlaybackPreparation.passthrough,
        );
        expect(
          await platform.preparePlaybackFile(
            inputPath: '/tmp/in.ogg',
            outputPath: '/tmp/out.m4a',
            contentType: 'audio/ogg',
            fileName: 'voice.ogg',
          ),
          isA<VoiceMessagePreparedPlaybackFile>()
              .having((file) => file.path, 'path', '/tmp/in.ogg')
              .having((file) => file.isTranscoded, 'isTranscoded', isFalse),
        );
        await expectLater(
          platform.convertOggToM4a(
            srcPath: '/tmp/in.ogg',
            destPath: '/tmp/out',
          ),
          throwsA(isA<VoiceMessageUnsupportedException>()),
        );
        expect(await platform.tryExtractWaveform(path: '/tmp/in.ogg'), isNull);
      },
    );
  });

  group('method channel platform', () {
    const channel = MethodChannel('voice_message');

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('reports all current Darwin capabilities as available', () {
      final platform = MethodChannelVoiceMessage();

      expect(platform.capabilities.canConvertOggToM4a, isTrue);
      expect(platform.capabilities.canConvertM4aToOgg, isTrue);
      expect(platform.capabilities.canExtractWaveform, isTrue);
      expect(platform.capabilities.canPreparePlayback, isTrue);
    });

    test('selects transcode preparation for ogg opus style inputs', () {
      final platform = MethodChannelVoiceMessage();

      expect(
        platform.playbackPreparationFor(
          contentType: 'audio/ogg',
          fileName: 'voice.ogg',
        ),
        VoiceMessagePlaybackPreparation.convertOggOpusToM4a,
      );
      expect(
        platform.playbackPreparationFor(
          contentType: 'audio/mp4',
          fileName: 'voice.m4a',
        ),
        VoiceMessagePlaybackPreparation.passthrough,
      );
    });

    test('sends expected method channel payloads', () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            if (call.method == 'extractWaveform') {
              return <int>[1, 2, 3];
            }
            return null;
          });

      final platform = MethodChannelVoiceMessage();
      await platform.convertOggToM4a(
        srcPath: '/tmp/in.ogg',
        destPath: '/tmp/out.m4a',
      );
      await platform.convertM4aToOgg(
        srcPath: '/tmp/in.m4a',
        destPath: '/tmp/out.ogg',
      );
      final samples = await platform.extractWaveform(
        path: '/tmp/in.ogg',
        samplesCount: 12,
      );

      expect(samples, <int>[1, 2, 3]);
      expect(calls.map((call) => call.method), <String>[
        'convertOggToM4a',
        'convertM4aToOgg',
        'extractWaveform',
      ]);
      expect(calls[0].arguments, <String, String>{
        'srcPath': '/tmp/in.ogg',
        'destPath': '/tmp/out.m4a',
      });
      expect(calls[2].arguments, <String, Object>{
        'path': '/tmp/in.ogg',
        'samplesCount': 12,
      });
    });
  });
}
