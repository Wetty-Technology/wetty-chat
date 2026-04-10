import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../app/routing/route_names.dart';
import '../../../../../core/notifications/unread_badge_provider.dart';
import '../../../chat_timestamp_formatter.dart';
import '../../../conversation/application/conversation_draft_store.dart';
import '../../../conversation/domain/conversation_scope.dart';
import '../../../conversation/domain/launch_request.dart';
import '../../../models/chat_models.dart';
import '../../../models/message_models.dart';
import '../../../models/message_preview_formatter.dart';
import '../../../threads/application/thread_list_view_model.dart';
import '../../../threads/presentation/thread_list_row.dart';
import '../../../threads/presentation/thread_list_view.dart';
import '../../application/chat_list_view_model.dart';
import '../../data/chat_launch_service.dart';
import '../chat_list_segment.dart';
import '../models/merged_list_item.dart';
import 'chat_list_row.dart';
import 'swipe_to_action_row.dart';

class ChatListTabBody extends ConsumerWidget {
  const ChatListTabBody({
    super.key,
    required this.activeTab,
    required this.chatAsync,
    required this.threadAsync,
    required this.mergedItems,
    required this.scrollController,
    required this.supportsPullToRefresh,
    required this.onRefresh,
  });

  final ChatListTab activeTab;
  final AsyncValue<ChatListViewState> chatAsync;
  final AsyncValue<ThreadListViewState> threadAsync;
  final List<MergedListItem> mergedItems;
  final ScrollController scrollController;
  final bool supportsPullToRefresh;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (activeTab) {
      ChatListTab.groups => chatAsync.when(
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (error, _) => _ErrorState(
          error: error.toString(),
          onRetry: () => ref.invalidate(chatListViewModelProvider),
        ),
        data: (viewState) => _GroupsBody(
          viewState: viewState,
          scrollController: scrollController,
          supportsPullToRefresh: supportsPullToRefresh,
          onRefresh: onRefresh,
        ),
      ),
      ChatListTab.threads => const ThreadListView(embedded: true),
      ChatListTab.all => _MergedBody(
        chatAsync: chatAsync,
        threadAsync: threadAsync,
        mergedItems: mergedItems,
        scrollController: scrollController,
        supportsPullToRefresh: supportsPullToRefresh,
        onRefresh: onRefresh,
      ),
    };
  }
}

class _GroupsBody extends ConsumerWidget {
  const _GroupsBody({
    required this.viewState,
    required this.scrollController,
    required this.supportsPullToRefresh,
    required this.onRefresh,
  });

  final ChatListViewState viewState;
  final ScrollController scrollController;
  final bool supportsPullToRefresh;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (viewState.errorMessage != null && viewState.chats.isEmpty) {
      return _ErrorState(
        error: viewState.errorMessage!,
        onRetry: () => ref.invalidate(chatListViewModelProvider),
      );
    }
    if (viewState.chats.isEmpty) {
      return const Center(child: Text('No chats yet'));
    }

    if (supportsPullToRefresh) {
      return CustomScrollView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverRefreshControl(onRefresh: onRefresh),
          SliverList.builder(
            itemCount: viewState.chats.length,
            itemBuilder: (context, index) =>
                _ChatListRowBuilder(chat: viewState.chats[index]),
          ),
          if (viewState.isLoadingMore) const _LoadingMoreSliver(),
        ],
      );
    }

    return ListView.builder(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: viewState.chats.length + (viewState.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= viewState.chats.length) {
          return const _LoadingMoreRow();
        }
        return _ChatListRowBuilder(chat: viewState.chats[index]);
      },
    );
  }
}

class _MergedBody extends ConsumerWidget {
  const _MergedBody({
    required this.chatAsync,
    required this.threadAsync,
    required this.mergedItems,
    required this.scrollController,
    required this.supportsPullToRefresh,
    required this.onRefresh,
  });

  final AsyncValue<ChatListViewState> chatAsync;
  final AsyncValue<ThreadListViewState> threadAsync;
  final List<MergedListItem> mergedItems;
  final ScrollController scrollController;
  final bool supportsPullToRefresh;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (chatAsync is AsyncLoading && threadAsync is AsyncLoading) {
      return const Center(child: CupertinoActivityIndicator());
    }

    if (chatAsync is AsyncError && chatAsync.value == null) {
      return _ErrorState(
        error: (chatAsync as AsyncError).error.toString(),
        onRetry: () => ref.invalidate(chatListViewModelProvider),
      );
    }

    final chatViewState = chatAsync.value;
    final threadViewState = threadAsync.value;
    final chats = chatViewState?.chats ?? const [];
    final threads = threadViewState?.threads ?? const [];

    if (chats.isEmpty && threads.isEmpty) {
      return const Center(child: Text('No chats or threads yet'));
    }

    final isLoadingMore =
        (chatViewState?.isLoadingMore ?? false) ||
        (threadViewState?.isLoadingMore ?? false);

    if (supportsPullToRefresh) {
      return CustomScrollView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverRefreshControl(onRefresh: onRefresh),
          SliverList.builder(
            itemCount: mergedItems.length,
            itemBuilder: (context, index) =>
                _MergedListRow(item: mergedItems[index]),
          ),
          if (isLoadingMore) const _LoadingMoreSliver(),
        ],
      );
    }

    return ListView.builder(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: mergedItems.length + (isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= mergedItems.length) {
          return const _LoadingMoreRow();
        }
        return _MergedListRow(item: mergedItems[index]);
      },
    );
  }
}

class _MergedListRow extends StatelessWidget {
  const _MergedListRow({required this.item});

  final MergedListItem item;

  @override
  Widget build(BuildContext context) {
    return switch (item) {
      MergedChatItem(:final chat) => _ChatListRowBuilder(chat: chat),
      MergedThreadItem(:final thread) => SwipeToActionRow(
        key: ValueKey('thread-${thread.chatId}-${thread.threadRootId}'),
        icon: thread.unreadCount > 0
            ? CupertinoIcons.checkmark_alt
            : CupertinoIcons.mail,
        label: thread.unreadCount > 0 ? 'Read' : 'Unread',
        onAction: () {
          // TODO: implement when backend supports thread mark-read/unread from list
        },
        child: ThreadListRow(
          thread: thread,
          onTap: () {
            context.push(
              AppRoutes.threadDetail(
                thread.chatId,
                thread.threadRootId.toString(),
              ),
            );
          },
        ),
      ),
    };
  }
}

class _ChatListRowBuilder extends ConsumerWidget {
  const _ChatListRowBuilder({required this.chat});

  final ChatListItem chat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatName = chat.name?.isNotEmpty == true
        ? chat.name!
        : 'Chat ${chat.id}';
    final dateText = formatChatListTimestamp(context, chat.lastMessageAt);
    final lastMessage = chat.lastMessage;
    final draftText = ref
        .read(conversationDraftProvider)
        .getDraft(ConversationScope.chat(chatId: chat.id));

    final isMuted =
        chat.mutedUntil != null && chat.mutedUntil!.isAfter(DateTime.now());

    final isUnread = chat.unreadCount > 0;

    return SwipeToActionRow(
      key: ValueKey('chat-${chat.id}'),
      icon: isUnread ? CupertinoIcons.checkmark_alt : CupertinoIcons.mail,
      label: isUnread ? 'Read' : 'Unread',
      onAction: () {
        ref
            .read(chatListViewModelProvider.notifier)
            .toggleChatReadState(chatId: chat.id);
      },
      child: ChatListRow(
        chatName: chatName,
        timestampText: dateText,
        unreadCount: chat.unreadCount,
        senderName: lastMessage?.sender.name,
        lastMessageText: _messagePreviewText(lastMessage),
        draftText: draftText,
        isMuted: isMuted,
        onTap: () async {
          final launchRequest = await _launchRequestForChat(ref, chat);
          if (!context.mounted) return;
          final shouldRefresh = await context.push<bool>(
            AppRoutes.chatDetail(chat.id),
            extra: {'launchRequest': launchRequest},
          );
          if (shouldRefresh == true) {
            await Future.wait([
              ref.read(chatListViewModelProvider.notifier).refreshChats(),
              ref.read(unreadBadgeProvider.notifier).refresh(),
            ]);
          }
        },
      ),
    );
  }

  static Future<LaunchRequest> _launchRequestForChat(
    WidgetRef ref,
    ChatListItem chat,
  ) {
    return ref.read(chatLaunchServiceProvider).resolveLaunchRequest(chat);
  }

  static String _messagePreviewText(MessageItem? message) {
    if (message == null) return '';
    return formatMessagePreview(
      message: message.message,
      messageType: message.messageType,
      sticker: message.sticker,
      attachments: message.attachments,
      firstAttachmentKind: message.attachments.isNotEmpty
          ? message.attachments.first.kind
          : null,
      isDeleted: message.isDeleted,
      mentions: message.mentions,
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            CupertinoButton.filled(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingMoreSliver extends StatelessWidget {
  const _LoadingMoreSliver();

  @override
  Widget build(BuildContext context) {
    return const SliverToBoxAdapter(child: _LoadingMoreRow());
  }
}

class _LoadingMoreRow extends StatelessWidget {
  const _LoadingMoreRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Center(child: CupertinoActivityIndicator()),
    );
  }
}
