import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routing/route_names.dart';
import '../../chat_timestamp_formatter.dart';
import 'package:chahua/features/conversation/shared/domain/launch_request.dart';
import '../../list/presentation/widgets/chat_list_row.dart';
import '../../models/chat_models.dart';
import '../../models/message_models.dart';
import '../../models/message_preview_formatter.dart';
import '../application/group_list_v2_view_model.dart';

class GroupListV2View extends ConsumerWidget {
  const GroupListV2View({
    super.key,
    this.scrollController,
    this.supportsPullToRefresh = false,
  });

  final ScrollController? scrollController;
  final bool supportsPullToRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(groupListV2ViewModelProvider);

    return asyncState.when(
      loading: () => const Center(child: CupertinoActivityIndicator()),
      error: (error, _) => Center(child: Text(error.toString())),
      data: (viewState) {
        if (viewState.errorMessage != null && viewState.groups.isEmpty) {
          return Center(child: Text(viewState.errorMessage!));
        }
        if (viewState.groups.isEmpty) {
          return const Center(child: Text('No groups yet'));
        }

        if (supportsPullToRefresh) {
          return CustomScrollView(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              CupertinoSliverRefreshControl(
                onRefresh: () => ref
                    .read(groupListV2ViewModelProvider.notifier)
                    .refreshGroups(),
              ),
              SliverList.builder(
                itemCount: viewState.groups.length,
                itemBuilder: (context, index) =>
                    _GroupListV2Row(chat: viewState.groups[index]),
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
          itemCount:
              viewState.groups.length + (viewState.isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= viewState.groups.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CupertinoActivityIndicator()),
              );
            }
            return _GroupListV2Row(chat: viewState.groups[index]);
          },
        );
      },
    );
  }
}

class _GroupListV2Row extends StatelessWidget {
  const _GroupListV2Row({required this.chat});

  final ChatListItem chat;

  @override
  Widget build(BuildContext context) {
    final chatName = chat.name?.isNotEmpty == true
        ? chat.name!
        : 'Chat ${chat.id}';
    final dateText = formatChatListTimestamp(context, chat.lastMessageAt);
    final lastMessage = chat.lastMessage;
    final isMuted =
        chat.mutedUntil != null && chat.mutedUntil!.isAfter(DateTime.now());

    return Consumer(
      builder: (context, ref, _) => ChatListRow(
        chatName: chatName,
        avatarUrl: chat.avatarUrl,
        timestampText: dateText,
        unreadCount: chat.unreadCount,
        senderName: lastMessage?.sender.name,
        lastMessageText: _messagePreviewText(lastMessage),
        isMuted: isMuted,
        onTap: () {
          context.push(
            AppRoutes.chatDetail(chat.id),
            extra: {'launchRequest': _launchRequestForChat(chat)},
          );
        },
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
