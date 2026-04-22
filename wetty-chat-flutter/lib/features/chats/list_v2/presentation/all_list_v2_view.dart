import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routing/route_names.dart';
import '../../chat_timestamp_formatter.dart';
import 'package:chahua/features/conversation/shared/domain/launch_request.dart';
import '../../list/presentation/widgets/chat_list_row.dart';
import '../../list/presentation/widgets/swipe_to_action_row.dart';
import '../../models/chat_models.dart';
import '../../models/message_models.dart';
import '../../models/message_preview_formatter.dart';
import '../../threads/models/thread_models.dart';
import '../../threads/presentation/thread_list_row.dart';
import '../application/all_list_v2_models.dart';
import '../application/all_list_v2_view_model.dart';

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
    final asyncState = ref.watch(allListV2ViewModelProvider);

    return asyncState.when(
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (error, _) => Center(child: Text(error.toString())),
      data: (viewState) {
        if (viewState.errorMessage != null && viewState.items.isEmpty) {
          return Center(child: Text(viewState.errorMessage!));
        }
        if (viewState.items.isEmpty) {
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
                itemCount: viewState.items.length,
                itemBuilder: (context, index) =>
                    _AllListV2Row(item: viewState.items[index]),
              ),
              if (viewState.isLoadingMore)
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
          itemCount: viewState.items.length + (viewState.isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= viewState.items.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CupertinoActivityIndicator()),
              );
            }
            return _AllListV2Row(item: viewState.items[index]);
          },
        );
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

    return ChatListRow(
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
    return SwipeToActionRow(
      key: ValueKey('thread-all-v2-${thread.chatId}-${thread.threadRootId}'),
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
    );
  }
}
