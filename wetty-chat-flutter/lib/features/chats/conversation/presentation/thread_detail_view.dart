import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/style_config.dart';
import '../../../groups/metadata/application/group_metadata_view_model.dart';
import '../application/conversation_timeline_view_model.dart';
import '../domain/conversation_message.dart';
import '../domain/conversation_scope.dart';
import '../domain/launch_request.dart';
import '../../threads/data/thread_api_service.dart';
import '../../threads/data/thread_repository.dart';
import '../../threads/data/thread_subscription_provider.dart';
import 'conversation_surface.dart';

class ThreadDetailPage extends ConsumerStatefulWidget {
  const ThreadDetailPage({
    super.key,
    required this.chatId,
    required this.threadRootId,
    this.launchRequest = const LaunchRequest.latest(),
  });

  final String chatId;
  final String threadRootId;
  final LaunchRequest launchRequest;

  @override
  ConsumerState<ThreadDetailPage> createState() => _ThreadDetailPageState();
}

class _ThreadDetailPageState extends ConsumerState<ThreadDetailPage>
    with WidgetsBindingObserver {
  static const Duration _markReadCooldown = Duration(milliseconds: 500);

  int? _maxSeenMessageId;
  Timer? _markReadTimer;

  ConversationScope get scope => ConversationScope.thread(
    chatId: widget.chatId,
    threadRootId: widget.threadRootId,
  );

  ConversationTimelineArgs get _timelineArgs =>
      (scope: scope, launchRequest: widget.launchRequest);

  @override
  void initState() {
    super.initState();
    developer.log(
      'initState: chatId=${widget.chatId}, '
      'threadRootId=${widget.threadRootId}, '
      'identity=${identityHashCode(this)}',
      name: 'ThreadDetailView',
    );
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(
        ref
            .read(conversationTimelineViewModelProvider(_timelineArgs).notifier)
            .refreshEntryOnOpenIfNeeded(),
      );
    });
  }

  @override
  void dispose() {
    developer.log(
      'dispose: identity=${identityHashCode(this)}',
      name: 'ThreadDetailView',
    );
    _markReadTimer?.cancel();
    try {
      unawaited(_flushMarkAsRead());
    } catch (_) {}
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      try {
        unawaited(
          ref
              .read(
                conversationTimelineViewModelProvider(_timelineArgs).notifier,
              )
              .refreshOnResume(),
        );
      } catch (_) {}
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      try {
        unawaited(
          ref
              .read(
                conversationTimelineViewModelProvider(_timelineArgs).notifier,
              )
              .flushReadStatus(),
        );
        unawaited(_flushMarkAsRead());
      } catch (_) {}
    }
  }

  // ---------------------------------------------------------------------------
  // Thread mark-as-read
  // ---------------------------------------------------------------------------

  void _onLatestVisibleMessageChanged(ConversationMessage message) {
    final id = message.serverMessageId;
    if (id != null && (_maxSeenMessageId == null || id > _maxSeenMessageId!)) {
      _maxSeenMessageId = id;
    }
    _scheduleMarkAsRead();
  }

  void _scheduleMarkAsRead() {
    _markReadTimer?.cancel();
    _markReadTimer = Timer(_markReadCooldown, _flushMarkAsRead);
  }

  Future<void> _flushMarkAsRead() async {
    final messageId = _maxSeenMessageId;
    if (messageId == null) return;
    try {
      await ref
          .read(threadApiServiceProvider)
          .markThreadAsRead(int.parse(widget.threadRootId), messageId);
      ref
          .read(threadListStateProvider.notifier)
          .markThreadRead(
            threadRootId: int.parse(widget.threadRootId),
            messageId: messageId,
          );
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  ThreadSubscriptionArgs get _subscriptionArgs =>
      (chatId: widget.chatId, threadRootId: int.parse(widget.threadRootId));

  Widget _buildSubscriptionButton() {
    final subscriptionAsync = ref.watch(
      threadSubscriptionProvider(_subscriptionArgs),
    );
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: subscriptionAsync.isLoading
          ? null
          : () {
              ref
                  .read(threadSubscriptionProvider(_subscriptionArgs).notifier)
                  .toggle();
            },
      child: subscriptionAsync.when(
        loading: () => const CupertinoActivityIndicator(),
        error: (_, _) => const Icon(CupertinoIcons.bell),
        data: (subscribed) =>
            Icon(subscribed ? CupertinoIcons.bell_fill : CupertinoIcons.bell),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final metadataAsync = ref.watch(
      groupMetadataViewModelProvider(widget.chatId),
    );

    final chatName = metadataAsync.value?.name ?? 'Chat ${widget.chatId}';

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          unawaited(
            ref
                .read(
                  conversationTimelineViewModelProvider(_timelineArgs).notifier,
                )
                .flushReadStatus(),
          );
          unawaited(_flushMarkAsRead());
        }
      },
      child: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Thread',
                style: appTitleTextStyle(
                  context,
                  fontSize: AppFontSizes.appTitle,
                ),
              ),
              Text(
                chatName,
                style: appSecondaryTextStyle(
                  context,
                  fontSize: AppFontSizes.meta,
                ),
              ),
            ],
          ),
          trailing: _buildSubscriptionButton(),
        ),
        child: SafeArea(
          bottom: false,
          child: ConversationSurface(
            scope: scope,
            timelineArgs: _timelineArgs,
            logTag: 'ThreadDetailView',
            onLatestVisibleMessageChanged: _onLatestVisibleMessageChanged,
            onTapMention: (uid, mention) {
              developer.log(
                'TODO: open profile sheet for thread mention '
                'uid=$uid username=${mention?.username}',
                name: 'ThreadDetailView',
              );
            },
          ),
        ),
      ),
    );
  }
}
