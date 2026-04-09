import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show LinearProgressIndicator;
import 'package:media_kit/media_kit.dart';

import '../../../../../app/theme/style_config.dart';
import '../../../models/message_models.dart';

class VoiceMessageBubble extends StatefulWidget {
  const VoiceMessageBubble({
    super.key,
    required this.attachment,
    required this.isMe,
  });

  final AttachmentItem attachment;
  final bool isMe;

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  late final Player _player;
  StreamSubscription<Object>? _errorSubscription;
  bool _isPreparing = false;
  bool _hasOpened = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _errorSubscription = _player.stream.error.listen((error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
        _isPreparing = false;
      });
    });
    unawaited(_prepare());
  }

  @override
  void dispose() {
    _errorSubscription?.cancel();
    unawaited(_player.dispose());
    super.dispose();
  }

  Future<void> _prepare() async {
    if (_hasOpened || _isPreparing || widget.attachment.url.isEmpty) {
      return;
    }
    setState(() {
      _isPreparing = true;
      _errorMessage = null;
    });
    try {
      await _player.open(Media(widget.attachment.url), play: false);
      if (!mounted) {
        return;
      }
      setState(() {
        _hasOpened = true;
        _isPreparing = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
        _isPreparing = false;
      });
    }
  }

  Future<void> _togglePlayback(bool isPlaying) async {
    if (_errorMessage != null || widget.attachment.url.isEmpty) {
      await _prepare();
      return;
    }
    if (!_hasOpened) {
      await _prepare();
    }
    if (isPlaying) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  String _formatDuration(Duration value) {
    final totalSeconds = value.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final background = widget.isMe
        ? context.appColors.chatAttachmentChipSent
        : context.appColors.chatAttachmentChipReceived;

    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: StreamBuilder<bool>(
        stream: _player.stream.playing,
        initialData: false,
        builder: (context, playingSnapshot) {
          final isPlaying = playingSnapshot.data ?? false;
          return StreamBuilder<Duration>(
            stream: _player.stream.position,
            initialData: Duration.zero,
            builder: (context, positionSnapshot) {
              return StreamBuilder<Duration>(
                stream: _player.stream.duration,
                initialData: Duration.zero,
                builder: (context, durationSnapshot) {
                  final position = positionSnapshot.data ?? Duration.zero;
                  final duration = durationSnapshot.data ?? Duration.zero;
                  final progress = duration.inMilliseconds <= 0
                      ? 0.0
                      : (position.inMilliseconds / duration.inMilliseconds)
                            .clamp(0, 1)
                            .toDouble();

                  return Row(
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(32, 32),
                        onPressed: _isPreparing
                            ? null
                            : () => unawaited(_togglePlayback(isPlaying)),
                        child: _isPreparing
                            ? const CupertinoActivityIndicator(radius: 9)
                            : Icon(
                                isPlaying
                                    ? CupertinoIcons.pause_solid
                                    : CupertinoIcons.play_fill,
                                size: 18,
                                color: CupertinoColors.activeBlue.resolveFrom(
                                  context,
                                ),
                              ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 4,
                                color: CupertinoColors.activeBlue.resolveFrom(
                                  context,
                                ),
                                backgroundColor: CupertinoColors.systemGrey4
                                    .resolveFrom(context),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _errorMessage != null
                                  ? 'Audio unavailable'
                                  : '${_formatDuration(position)} / ${_formatDuration(duration)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: appTextStyle(
                                context,
                                fontSize: AppFontSizes.meta,
                                color: context.appColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
