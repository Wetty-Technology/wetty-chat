import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/route_names.dart';
import 'package:chahua/features/conversation/shared/domain/launch_request.dart';
import 'package:chahua/features/shared/model/message/message.dart';
import '../../shared/presentation/chat_timestamp_formatter.dart';
import 'widgets/chat_list_row.dart';
import 'widgets/swipe_to_action_row.dart';
import '../model/chat_list_item.dart';
import '../../chats/threads/models/thread_models.dart';
import 'widgets/thread_list_row.dart';
import '../application/all_list_v2_models.dart';
import '../application/all_list_v2_projection.dart';
import '../application/all_list_v2_view_model.dart';
import '../application/group_list_v2_view_model.dart';
import '../application/thread_list_v2_view_model.dart';

class AllListV2View extends ConsumerWidget {
  const AllListV2View({
    super.key,
    this.scrollController,
    this.supportsPullToRefresh = false,
  });

  final ScrollController? scrollController;
  final bool supportsPullToRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(allListV2ItemsProvider);
    final uiState = ref.watch(allListV2ViewModelProvider);
    final groupAsync = ref.watch(groupListV2ViewModelProvider);
    final threadAsync = ref.watch(threadListV2ViewModelProvider);
    final isInitialLoading =
        items.isEmpty && groupAsync.isLoading && threadAsync.isLoading;

    if (isInitialLoading) {
      return const Center(child: CupertinoActivityIndicator());
    }

    if (uiState.errorMessage != null && items.isEmpty) {
      return Center(child: Text(uiState.errorMessage!));
    }

    if (items.isEmpty) {
      return const Center(child: Text('No chats or threads yet'));
    }

    if (supportsPullToRefresh) {
      return CustomScrollView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverRefreshControl(
            onRefresh: () =>
                ref.read(allListV2ViewModelProvider.notifier).refreshAll(),
          ),
          SliverList.builder(
            itemCount: items.length,
            itemBuilder: (context, index) => _AllListV2Row(item: items[index]),
          ),
          if (uiState.isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CupertinoActivityIndicator()),
              ),
            ),
        ],
      );
    }

    return ListView.builder(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: items.length + (uiState.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CupertinoActivityIndicator()),
          );
        }
        return _AllListV2Row(item: items[index]);
      },
    );
  }
}

class _AllListV2Row extends StatelessWidget {
  const _AllListV2Row({required this.item});

  final AllListV2Item item;

  @override
  Widget build(BuildContext context) {
    return switch (item) {
      AllGroupListV2Item(:final group) => _AllGroupListV2Row(group: group),
      AllThreadListV2Item(:final thread) => _AllThreadListV2Row(thread: thread),
    };
  }
}

class _AllGroupListV2Row extends StatelessWidget {
  const _AllGroupListV2Row({required this.group});

  final ChatListItem group;

  @override
  Widget build(BuildContext context) {
    final chatName = group.name?.isNotEmpty == true
        ? group.name!
        : 'Chat ${group.id}';
    final dateText = formatChatListTimestamp(context, group.lastMessageAt);
    final lastMessage = group.lastMessage;
    final isMuted =
        group.mutedUntil != null && group.mutedUntil!.isAfter(DateTime.now());
    final isUnread = group.unreadCount > 0;

    return Consumer(
      builder: (context, ref, _) => SwipeToActionRow(
        key: ValueKey('group-all-v2-${group.id}'),
        icon: isUnread ? CupertinoIcons.checkmark_alt : CupertinoIcons.mail,
        label: isUnread ? 'Read' : 'Unread',
        onAction: () => ref
            .read(groupListV2ViewModelProvider.notifier)
            .toggleGroupReadState(chatId: group.id),
        child: ChatListRow(
          chatName: chatName,
          avatarUrl: group.avatarUrl,
          timestampText: dateText,
          unreadCount: group.unreadCount,
          senderName: lastMessage?.sender.name,
          lastMessageText: _messagePreviewText(lastMessage),
          isMuted: isMuted,
          onTap: () {
            context.push(
              AppRoutes.chatDetail(group.id),
              extra: {'launchRequest': _launchRequestForChat(group)},
            );
          },
        ),
      ),
    );
  }

  static LaunchRequest _launchRequestForChat(ChatListItem chat) {
    final lastReadMessageId = int.tryParse(chat.lastReadMessageId ?? '');
    if (chat.unreadCount <= 0 || lastReadMessageId == null) {
      return const LaunchRequest.latest();
    }
    return LaunchRequest.unread(lastReadMessageId: lastReadMessageId);
  }

  static String _messagePreviewText(MessageItem? message) {
    if (message == null) {
      return '';
    }
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

class _AllThreadListV2Row extends StatelessWidget {
  const _AllThreadListV2Row({required this.thread});

  final ThreadListItem thread;

  @override
  Widget build(BuildContext context) {
    return ThreadListRow(
      thread: thread,
      onTap: () {
        context.push(
          AppRoutes.threadDetail(thread.chatId, thread.threadRootId.toString()),
        );
      },
    );
  }
}
