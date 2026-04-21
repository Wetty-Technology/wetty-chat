import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat_timestamp_formatter.dart';
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
    final viewState = ref.watch(groupListV2ViewModelProvider);

    if (viewState.errorMessage != null && viewState.groups.isEmpty) {
      return Center(child: Text(viewState.errorMessage!));
    }
    if (viewState.isLoading) {
      return const Center(child: CupertinoActivityIndicator());
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
          const CupertinoSliverRefreshControl(onRefresh: _noopRefresh),
          SliverList.builder(
            itemCount: viewState.groups.length,
            itemBuilder: (context, index) =>
                _GroupListV2Row(chat: viewState.groups[index]),
          ),
        ],
      );
    }

    return ListView.builder(
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: viewState.groups.length,
      itemBuilder: (context, index) =>
          _GroupListV2Row(chat: viewState.groups[index]),
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

    return ChatListRow(
      chatName: chatName,
      avatarUrl: chat.avatarUrl,
      timestampText: dateText,
      unreadCount: chat.unreadCount,
      senderName: lastMessage?.sender.name,
      lastMessageText: _messagePreviewText(lastMessage),
      isMuted: isMuted,
      onTap: () {
        // TODO(codex): Wire navigation once the old list flow is swapped to list_v2.
      },
    );
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

Future<void> _noopRefresh() async {}
