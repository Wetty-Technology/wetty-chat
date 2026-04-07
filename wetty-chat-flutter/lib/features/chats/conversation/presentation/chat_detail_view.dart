import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/routing/route_names.dart';
import '../../../../app/theme/style_config.dart';
import '../../../../core/session/dev_session_store.dart';
import '../../../../core/settings/app_settings_store.dart';
import '../../../../shared/presentation/app_divider.dart';
import '../application/conversation_composer_view_model.dart';
import '../application/conversation_timeline_view_model.dart';
import '../domain/conversation_message.dart';
import '../domain/conversation_scope.dart';
import '../domain/launch_request.dart';
import '../domain/timeline_entry.dart';
import 'anchored_timeline_view.dart';
import 'conversation_composer_bar.dart';
import 'message_row.dart';

class ChatDetailPage extends ConsumerStatefulWidget {
  const ChatDetailPage({
    super.key,
    required this.chatId,
    required this.chatName,
    this.launchRequest = const LaunchRequest.latest(),
  });

  final String chatId;
  final String chatName;
  final LaunchRequest launchRequest;

  @override
  ConsumerState<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends ConsumerState<ChatDetailPage>
    with WidgetsBindingObserver {
  static const double _liveEdgeScrollThreshold = 50;
  static const double _timelineEndPadding = 12;

  final ScrollController _timelineScrollController = ScrollController();

  bool _isPopping = false;
  bool _isAtLiveEdge = true;
  int _viewportGeneration = 0;
  Key _timelineViewportKey = const ValueKey<int>(0);

  ConversationScope get scope => ConversationScope.chat(widget.chatId);

  ConversationTimelineArgs get _timelineArgs =>
      (scope: scope, launchRequest: widget.launchRequest);

  @override
  void initState() {
    super.initState();
    developer.log(
      'initState: chatId=${widget.chatId}, '
      'launchRequest=${widget.launchRequest.intent}/'
      '${widget.launchRequest.messageId}, '
      'identity=${identityHashCode(this)}',
      name: 'ChatDetailView',
    );
    _timelineScrollController.addListener(_onTimelineScroll);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    developer.log(
      'dispose: identity=${identityHashCode(this)}',
      name: 'ChatDetailView',
    );
    WidgetsBinding.instance.removeObserver(this);
    _timelineScrollController.removeListener(_onTimelineScroll);
    _timelineScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
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
                  .valueOrNull
                  ?.shouldRefreshChats ==
              true,
    );
  }

  void _showMessageActions(ConversationMessage message) {
    if (message.isDeleted) {
      return;
    }
    final currentUserId = ref.read(devSessionProvider);
    final isOwn = message.sender.uid == currentUserId;
    final composerNotifier = ref.read(
      conversationComposerViewModelProvider(scope).notifier,
    );

    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              composerNotifier.beginReply(message);
            },
            child: const Text('Reply'),
          ),
          if (isOwn)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                composerNotifier.clearAttachments();
                composerNotifier.beginEdit(message);
              },
              child: const Text('Edit'),
            ),
          if (isOwn)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(context);
                _confirmDelete(message);
              },
              child: const Text('Delete'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _confirmDelete(ConversationMessage message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref
                    .read(conversationComposerViewModelProvider(scope).notifier)
                    .delete(message);
              } catch (error) {
                if (mounted) {
                  _showErrorDialog('$error');
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _onTimelineScroll() {
    if (!mounted || !_timelineScrollController.hasClients) return;
    final viewState = ref
        .read(conversationTimelineViewModelProvider(_timelineArgs))
        .valueOrNull;
    if (viewState == null) return;

    // Live edge detection: in liveLatest mode, offset 0 = at anchor (bottom).
    // Small positive offsets mean content was appended below.
    final position = _timelineScrollController.position;
    final isAtLiveEdge =
        !viewState.canLoadNewer &&
        (position.maxScrollExtent - position.pixels) < _liveEdgeScrollThreshold;
    if (_isAtLiveEdge != isAtLiveEdge) {
      setState(() {
        _isAtLiveEdge = isAtLiveEdge;
      });
    }

    _reportVisibleMessages(viewState);
  }

  void _onNearOlderEdge() {
    final viewState = ref
        .read(conversationTimelineViewModelProvider(_timelineArgs))
        .valueOrNull;
    if (viewState == null ||
        !viewState.canLoadOlder ||
        viewState.isLoadingOlder) {
      return;
    }
    // No position preservation needed — the center key keeps the anchor stable.
    unawaited(
      ref
          .read(conversationTimelineViewModelProvider(_timelineArgs).notifier)
          .loadOlder(),
    );
  }

  void _onNearNewerEdge() {
    final viewState = ref
        .read(conversationTimelineViewModelProvider(_timelineArgs))
        .valueOrNull;
    if (viewState == null ||
        !viewState.canLoadNewer ||
        viewState.isLoadingNewer) {
      return;
    }
    unawaited(
      ref
          .read(conversationTimelineViewModelProvider(_timelineArgs).notifier)
          .loadNewer(),
    );
  }

  /// Report visible messages for read-status tracking.
  /// In the center-key model we don't have precise per-item visibility,
  /// so we report all messages in the current window. This is safe because
  /// [onMessageVisible] only tracks the max seen message ID and debounces.
  void _reportVisibleMessages(ConversationTimelineState viewState) {
    final notifier = ref.read(
      conversationTimelineViewModelProvider(_timelineArgs).notifier,
    );
    for (final entry in viewState.entries) {
      if (entry is TimelineMessageEntry) {
        notifier.onMessageVisible(entry.message);
      }
    }
  }

  Future<void> _scrollToLatest() async {
    await ref
        .read(conversationTimelineViewModelProvider(_timelineArgs).notifier)
        .jumpToLatest();
  }

  Future<void> _jumpToMessage(int messageId) async {
    final notifier = ref.read(
      conversationTimelineViewModelProvider(_timelineArgs).notifier,
    );
    await notifier.jumpToMessage(messageId);
  }

  void _resetViewportSession(int sessionId) {
    _timelineViewportKey = ValueKey<int>(sessionId);
  }

  void _showErrorDialog(String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationBarTitle(BuildContext context) {
    return Text(
      widget.chatName.isEmpty ? 'Chat ${widget.chatId}' : widget.chatName,
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
            onPressed: () => context.push(
              AppRoutes.chatSettings(widget.chatId),
              extra: {'currentName': widget.chatName},
            ),
            child: const Icon(
              CupertinoIcons.gear_solid,
              size: IconSizes.iconSize,
            ),
          ),
        ],
      ),
    );
  }

  EdgeInsets _timelinePadding(BuildContext context) {
    return EdgeInsets.only(top: 8, bottom: _timelineEndPadding);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final timelineAsync = ref.watch(
      conversationTimelineViewModelProvider(_timelineArgs),
    );
    final settings = ref.watch(appSettingsProvider);

    timelineAsync.whenData((state) {
      final locatePlan = state.locatePlan;
      developer.log(
        'whenData: locatePlan=${locatePlan?.placement}, '
        'mode=${state.windowMode}, '
        'anchorIdx=${state.anchorEntryIndex}/${state.entries.length}, '
        'alignment=${state.anchorAlignment}, '
        'canLoadNewer=${state.canLoadNewer}, '
        'viewportKey=$_timelineViewportKey, '
        'generation=$_viewportGeneration',
        name: 'ChatDetailView',
      );
      if (locatePlan != null) {
        // Consume the locate plan: re-key the timeline view to force
        // CustomScrollView to rebuild with the new anchor position,
        // then clear it so it isn't re-applied on unrelated rebuilds.
        _viewportGeneration += 1;
        _isAtLiveEdge =
            locatePlan.placement == ConversationLocatePlacement.liveEdge;
        _resetViewportSession(_viewportGeneration);
        developer.log(
          'applied locatePlan: placement=${locatePlan.placement}, '
          'isAtLiveEdge=$_isAtLiveEdge, '
          'newKey=$_timelineViewportKey, '
          'newGeneration=$_viewportGeneration',
          name: 'ChatDetailView',
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          ref
              .read(
                conversationTimelineViewModelProvider(_timelineArgs).notifier,
              )
              .consumeLocatePlan();
        });
      }
      if (state.infoMessage != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          _showErrorDialog(state.infoMessage!);
          ref
              .read(
                conversationTimelineViewModelProvider(_timelineArgs).notifier,
              )
              .clearInfoMessage();
        });
      }
    });

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
          middle: _buildNavigationBarTitle(context),
          leading: CupertinoNavigationBarBackButton(onPressed: _popWithResult),
          trailing: _buildNavigationBarTrailing(),
        ),
        child: SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    color: colors.chatBackground,
                    child: Stack(
                      children: [
                        timelineAsync.when(
                          loading: () =>
                              const Center(child: CupertinoActivityIndicator()),
                          error: (error, _) => Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('$error', textAlign: TextAlign.center),
                                  const SizedBox(height: 16),
                                  CupertinoButton.filled(
                                    onPressed: () => ref.invalidate(
                                      conversationTimelineViewModelProvider(
                                        _timelineArgs,
                                      ),
                                    ),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          data: (viewState) => _buildTimeline(
                            viewState,
                            settings.fontSize,
                            _timelinePadding(context),
                          ),
                        ),
                        if (timelineAsync.valueOrNull case final viewState?
                            when _shouldShowJumpToLatest(viewState))
                          Positioned(
                            right: 16,
                            bottom: 16,
                            child: CupertinoButton(
                              padding: EdgeInsets.zero,
                              onPressed: _scrollToLatest,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: CupertinoColors.systemGrey5
                                      .resolveFrom(context),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(CupertinoIcons.chevron_down),
                                    if ((timelineAsync
                                                .valueOrNull
                                                ?.pendingLiveCount ??
                                            0) >
                                        0)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 6),
                                        child: Text(
                                          '${timelineAsync.valueOrNull!.pendingLiveCount}',
                                          style: appTextStyle(
                                            context,
                                            fontSize: AppFontSizes.meta,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                ConversationComposerBar(
                  scope: scope,
                  onMessageSent: _scrollToLatest,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _shouldShowJumpToLatest(ConversationTimelineState state) {
    if (state.windowMode != ConversationWindowMode.liveLatest) {
      return true;
    }
    if (state.canLoadNewer) {
      return true;
    }
    return !_isAtLiveEdge;
  }

  Widget _buildTimeline(
    ConversationTimelineState viewState,
    double chatMessageFontSize,
    EdgeInsets contentPadding,
  ) {
    if (viewState.entries.isEmpty) {
      return const Center(child: Text('No messages yet'));
    }
    developer.log(
      '_buildTimeline: key=$_timelineViewportKey, '
      'anchorIdx=${viewState.anchorEntryIndex}/${viewState.entries.length}, '
      'alignment=${viewState.anchorAlignment}, '
      'mode=${viewState.windowMode}',
      name: 'ChatDetailView',
    );
    return AnchoredTimelineView(
      key: _timelineViewportKey,
      entries: viewState.entries,
      anchorIndex: viewState.anchorEntryIndex,
      anchorAlignment: viewState.anchorAlignment,
      scrollController: _timelineScrollController,
      onNearOlderEdge: _onNearOlderEdge,
      onNearNewerEdge: _onNearNewerEdge,
      topPadding: contentPadding.top,
      bottomPadding: contentPadding.bottom,
      entryBuilder: (context, entry, index) {
        return switch (entry) {
          TimelineMessageEntry(:final message) => MessageRow(
            key: ValueKey(message.stableKey),
            message: message,
            chatMessageFontSize: chatMessageFontSize,
            isHighlighted:
                viewState.highlightedMessageId == message.serverMessageId,
            onLongPress: () => _showMessageActions(message),
            onReply: () => ref
                .read(conversationComposerViewModelProvider(scope).notifier)
                .beginReply(message),
            onTapReply: message.replyToMessage != null
                ? () => _jumpToMessage(message.replyToMessage!.id)
                : null,
          ),
          TimelineDateSeparatorEntry(:final day) => _buildDateSeparator(day),
          TimelineUnreadMarkerEntry() => _buildUnreadDivider(),
          TimelineHistoryGapOlderEntry() => _buildGapLabel(
            'Pull to load older messages',
          ),
          TimelineHistoryGapNewerEntry() => _buildGapLabel(
            'Scroll down to newer messages',
          ),
          TimelineLoadingOlderEntry() => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CupertinoActivityIndicator()),
          ),
          TimelineLoadingNewerEntry() => const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CupertinoActivityIndicator()),
          ),
        };
      },
    );
  }

  Widget _buildDateSeparator(DateTime day) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey4.resolveFrom(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
            style: appOnDarkTextStyle(context, fontSize: AppFontSizes.meta),
          ),
        ),
      ),
    );
  }

  Widget _buildUnreadDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(child: AppDivider(color: CupertinoColors.systemGrey4)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey4.resolveFrom(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Unread Messages',
              style: appOnDarkTextStyle(
                context,
                fontSize: AppFontSizes.meta,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Expanded(child: AppDivider(color: CupertinoColors.systemGrey4)),
        ],
      ),
    );
  }

  Widget _buildGapLabel(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Text(
          text,
          style: appSecondaryTextStyle(context, fontSize: AppFontSizes.meta),
        ),
      ),
    );
  }
}
