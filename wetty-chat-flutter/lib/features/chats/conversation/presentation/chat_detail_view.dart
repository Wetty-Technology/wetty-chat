import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routing/route_names.dart';
import '../../../../app/theme/style_config.dart';
import '../../../../core/notifications/unread_badge_provider.dart';
import '../../../groups/metadata/application/group_metadata_view_model.dart';
import '../../../groups/metadata/data/group_metadata_models.dart';
import '../../list/application/chat_list_view_model.dart';
import '../../models/message_models.dart';
import '../../threads/application/thread_list_view_model.dart';
import '../application/conversation_composer_view_model.dart';
import '../application/conversation_timeline_view_model.dart';
import '../domain/conversation_scope.dart';
import '../domain/launch_request.dart';
import 'conversation_composer_bar.dart';
import 'timeline/conversation_timeline.dart';
import '../../../../features/stickers/presentation/sticker_picker_panel.dart';
import '../../../../features/stickers/presentation/sticker_preview_modal.dart';

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
  final ConversationTimelineController _timelineController =
      ConversationTimelineController();

  bool _isPopping = false;
  bool _isStickerPickerOpen = false;

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
                  .value
                  ?.shouldRefreshChats ==
              true,
    );
  }

  Future<void> _refreshConversationLists() async {
    try {
      await Future.wait([
        ref.read(chatListViewModelProvider.notifier).refreshChats(),
        ref.read(threadListViewModelProvider.notifier).refreshThreads(),
        ref.read(unreadBadgeProvider.notifier).refresh(),
      ]);
    } catch (_) {
      // Keep detail interaction responsive; websocket/manual refresh remains fallback.
    }
  }

  Future<void> _handleMessageSent() async {
    await _timelineController.scrollToLatest();
    unawaited(_refreshConversationLists());
  }

  void _toggleStickerPicker() {
    setState(() {
      _isStickerPickerOpen = !_isStickerPickerOpen;
      if (_isStickerPickerOpen) {
        FocusScope.of(context).unfocus();
      }
    });
  }

  void _handleStickerSelected(StickerSummary sticker) {
    if (sticker.id == null) return;
    unawaited(
      ref
          .read(conversationComposerViewModelProvider(scope).notifier)
          .sendSticker(sticker),
    );
    setState(() {
      _isStickerPickerOpen = false;
    });
    unawaited(_handleMessageSent());
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
    final colors = context.appColors;
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
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    color: colors.chatBackground,
                    child: ConversationTimeline(
                      scope: scope,
                      timelineArgs: _timelineArgs,
                      controller: _timelineController,
                      logTag: 'ChatDetailView',
                      onOpenThread: (message) => context.push(
                        AppRoutes.threadDetail(
                          widget.chatId,
                          message.serverMessageId.toString(),
                        ),
                      ),
                      onTapSticker: (message) {
                        final stickerId = message.sticker?.id;
                        if (stickerId != null) {
                          showStickerPreviewModal(context, stickerId);
                        }
                      },
                    ),
                  ),
                ),
                ColoredBox(
                  color: colors.backgroundSecondary,
                  child: SafeArea(
                    top: false,
                    bottom: !_isStickerPickerOpen,
                    child: ConversationComposerBar(
                      scope: scope,
                      onMessageSent: _handleMessageSent,
                      onToggleStickerPicker: _toggleStickerPicker,
                      isStickerPickerOpen: _isStickerPickerOpen,
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: _isStickerPickerOpen
                      ? SafeArea(
                          top: false,
                          child: StickerPickerPanel(
                            onStickerSelected: _handleStickerSelected,
                            onClose: () =>
                                setState(() => _isStickerPickerOpen = false),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
