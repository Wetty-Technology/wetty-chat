import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routing/route_names.dart';
import '../../../../app/theme/style_config.dart';
import '../../../groups/metadata/application/group_metadata_view_model.dart';
import '../../../groups/metadata/data/group_metadata_models.dart';
import '../application/conversation_timeline_view_model.dart';
import '../domain/conversation_scope.dart';
import '../domain/launch_request.dart';
import 'conversation_surface.dart';

class ChatDetailPage extends ConsumerStatefulWidget {
  const ChatDetailPage({
    super.key,
    required this.chatId,
    this.launchRequest = const LaunchRequest.latest(),
  });

  final String chatId;
  final LaunchRequest launchRequest;

  @override
  ConsumerState<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends ConsumerState<ChatDetailPage>
    with WidgetsBindingObserver {
  bool _isPopping = false;

  ConversationScope get scope => ConversationScope.chat(chatId: widget.chatId);

  ConversationTimelineArgs get _timelineArgs =>
      (scope: scope, launchRequest: widget.launchRequest);

  @override
  void initState() {
    super.initState();
    developer.log(
      'initState: chatId=${widget.chatId}, '
      'launchRequest=${widget.launchRequest}, '
      'identity=${identityHashCode(this)}',
      name: 'ChatDetailView',
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
      name: 'ChatDetailView',
    );
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
      // Best-effort flush — provider may already be disposed if the
      // app is being terminated, so guard with try/catch.
      try {
        unawaited(
          ref
              .read(
                conversationTimelineViewModelProvider(_timelineArgs).notifier,
              )
              .flushReadStatus(),
        );
      } catch (_) {}
    }
  }

  Future<void> _popWithResult() async {
    if (_isPopping) {
      return;
    }
    _isPopping = true;
    final notifier = ref.read(
      conversationTimelineViewModelProvider(_timelineArgs).notifier,
    );
    final didSync = await notifier.flushReadStatus();
    if (!mounted) {
      return;
    }
    context.pop(
      didSync ||
          ref
                  .read(conversationTimelineViewModelProvider(_timelineArgs))
                  .value
                  ?.shouldRefreshChats ==
              true,
    );
  }

  String _resolveChatTitle(AsyncValue<ChatMetadata> metadataAsync) {
    final resolvedName = metadataAsync.value?.name;
    if (resolvedName != null && resolvedName.trim().isNotEmpty) {
      return resolvedName;
    }
    return 'Chat ${widget.chatId}';
  }

  Widget _buildNavigationBarTitle(
    BuildContext context,
    AsyncValue<ChatMetadata> metadataAsync,
  ) {
    return Text(
      _resolveChatTitle(metadataAsync),
      style: appTitleTextStyle(context, fontSize: AppFontSizes.appTitle),
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildNavigationBarTrailing() {
    return SizedBox(
      width: 72,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            onPressed: () => context.push(AppRoutes.chatMembers(widget.chatId)),
            child: const Icon(CupertinoIcons.person_2_fill, size: 22),
          ),
          const SizedBox(width: 12),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            onPressed: () =>
                context.push(AppRoutes.chatSettings(widget.chatId)),
            child: const Icon(
              CupertinoIcons.gear_solid,
              size: IconSizes.iconSize,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final metadataAsync = ref.watch(
      groupMetadataViewModelProvider(widget.chatId),
    );

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
        }
      },
      child: CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: _buildNavigationBarTitle(context, metadataAsync),
          leading: CupertinoNavigationBarBackButton(onPressed: _popWithResult),
          trailing: _buildNavigationBarTrailing(),
        ),
        child: SafeArea(
          bottom: false,
          child: ConversationSurface(
            scope: scope,
            timelineArgs: _timelineArgs,
            logTag: 'ChatDetailView',
            onOpenThread: (message) => context.push(
              AppRoutes.nestedThreadDetail(
                widget.chatId,
                message.serverMessageId.toString(),
              ),
            ),
            onTapMention: (uid, mention) {
              developer.log(
                'TODO: open profile sheet for mention '
                'uid=$uid username=${mention?.username}',
                name: 'ChatDetailView',
              );
            },
          ),
        ),
      ),
    );
  }
}
