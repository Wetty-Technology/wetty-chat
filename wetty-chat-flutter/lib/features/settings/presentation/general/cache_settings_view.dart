import 'dart:developer';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/core/cache/app_cache_service.dart';
import 'package:chahua/features/audio/application/audio_source_resolver_service.dart';
import 'package:chahua/features/audio/application/audio_duration_probe_service.dart';
import 'package:chahua/features/audio/application/audio_waveform_cache_service.dart';
import 'package:chahua/features/conversation/timeline/presentation/voice_message_playback_controller_v2.dart';
import 'package:chahua/features/conversation/timeline/presentation/voice_message_presentation_provider_v2.dart';
import 'package:chahua/l10n/app_localizations.dart';

final mediaCacheUsageProvider = FutureProvider<AppCacheUsageSummary>((ref) {
  log('Recomputing app cache usage', name: 'CacheSettingsPage');
  return ref.watch(appCacheServiceProvider).estimateUsage();
});

class CacheSettingsPage extends ConsumerStatefulWidget {
  const CacheSettingsPage({super.key});

  @override
  ConsumerState<CacheSettingsPage> createState() => _CacheSettingsPageState();
}

class _CacheSettingsPageState extends ConsumerState<CacheSettingsPage> {
  bool _isClearing = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final usageAsync = ref.watch(mediaCacheUsageProvider);

    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.settingsCacheTitle),
      ),
      child: SafeArea(
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            CupertinoSliverRefreshControl(onRefresh: _refreshUsage),
            SliverToBoxAdapter(
              child: CupertinoListSection.insetGrouped(
                header: Text(l10n.settingsCacheSectionHeader),
                footer: Text(l10n.settingsCacheDescription),
                children: [
                  CupertinoListTile(
                    title: Text(l10n.settingsCacheUsage),
                    trailing: usageAsync.when(
                      data: (usage) => Text(
                        _formatBytes(usage.totalBytes),
                        textAlign: TextAlign.right,
                      ),
                      loading: () => const CupertinoActivityIndicator(),
                      error: (_, _) => Text(l10n.error),
                    ),
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: CupertinoListSection.insetGrouped(
                children: [
                  CupertinoListTile(
                    title: Text(
                      l10n.settingsClearCache,
                      style: appBodyTextStyle(
                        context,
                        color: CupertinoColors.destructiveRed,
                      ),
                    ),
                    trailing: _isClearing
                        ? const CupertinoActivityIndicator()
                        : const CupertinoListTileChevron(),
                    onTap: _isClearing ? null : () => _confirmAndClearCache(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshUsage() async {
    ref.invalidate(mediaCacheUsageProvider);
    await ref.read(mediaCacheUsageProvider.future);
  }

  Future<void> _confirmAndClearCache() async {
    final l10n = AppLocalizations.of(context)!;
    final shouldClear = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) {
        return CupertinoAlertDialog(
          title: Text(l10n.settingsClearCacheTitle),
          content: Text(l10n.settingsClearCacheMessage),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.settingsClearCache),
            ),
          ],
        );
      },
    );
    if (shouldClear != true || !mounted) {
      return;
    }

    setState(() {
      _isClearing = true;
    });
    try {
      await ref.read(appCacheServiceProvider).clearAll();
      ref.read(audioDurationProbeServiceProvider).clearMemory();
      ref.read(audioWaveformCacheServiceProvider).clearMemory();
      ref.invalidate(mediaCacheUsageProvider);
      ref.invalidate(audioDurationProbeServiceProvider);
      ref.invalidate(audioSourceResolverServiceProvider);
      ref.invalidate(audioWaveformCacheServiceProvider);
      ref.invalidate(voiceMessagePresentationV2Provider);
      ref.invalidate(voiceMessagePlaybackControllerV2Provider);
      await ref.read(mediaCacheUsageProvider.future);
    } finally {
      if (mounted) {
        setState(() {
          _isClearing = false;
        });
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }

    const units = <String>['KB', 'MB', 'GB', 'TB'];
    var value = bytes / 1024;
    var unitIndex = 0;
    while (value >= 1024 && unitIndex < units.length - 1) {
      value /= 1024;
      unitIndex += 1;
    }
    return '${value.toStringAsFixed(value >= 100 ? 0 : 1)} ${units[unitIndex]}';
  }
}
