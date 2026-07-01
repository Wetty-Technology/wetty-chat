import 'package:chahua/features/conversation/shared/domain/conversation_identity.dart';
import 'package:chahua/features/conversation/shared/domain/launch_request.dart';
import 'package:chahua/features/shared/model/message/message.dart';
import 'package:chahua/features/conversation/shared/presentation/conversation_surface_v2.dart';
import 'package:chahua/features/chat_list/application/group_list_v2_store.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:chahua/app/routing/route_names.dart';
import 'package:chahua/features/chat_list/presentation/chat_workspace_layout_scope.dart';
import 'package:chahua/l10n/app_localizations.dart';

class ChatDetailV2Page extends StatefulWidget {
  const ChatDetailV2Page({
    super.key,
    required this.chatId,
    this.launchRequest = const LaunchRequest.latest(),
  });

  final int chatId;
  final LaunchRequest launchRequest;

  @override
  State<ChatDetailV2Page> createState() => _ChatDetailV2PageState();
}

class _ChatDetailV2PageState extends State<ChatDetailV2Page> {
  ForwardSelectionNavigationState? _forwardSelectionNavigationState;

  void _handleForwardSelectionChanged(
    ForwardSelectionNavigationState? selectionState,
  ) {
    if (!mounted) {
      return;
    }
    if (_forwardSelectionNavigationState == selectionState) {
      return;
    }
    setState(() {
      _forwardSelectionNavigationState = selectionState;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSplitLayout = ChatWorkspaceLayoutScope.isSplitLayout(context);
    final ConversationIdentity identity = (
      chatId: widget.chatId,
      threadRootId: null,
    );
    final selectionState = _forwardSelectionNavigationState;
    return CupertinoPageScaffold(
      resizeToAvoidBottomInset: false,
      navigationBar: CupertinoNavigationBar(
        automaticallyImplyLeading: selectionState == null && !isSplitLayout,
        leading: selectionState == null
            ? null
            : _ForwardSelectionCancelButton(onPressed: selectionState.onCancel),
        middle: selectionState == null
            ? _ChatDetailTitle(chatId: widget.chatId)
            : _ForwardSelectionTitle(
                selectedCount: selectionState.selectedCount,
              ),
        trailing: selectionState == null
            ? _ChatDetailActions(chatId: widget.chatId)
            : _ForwardSelectionForwardButton(
                onPressed: selectionState.onForward,
              ),
      ),
      child: SafeArea(
        bottom: false,
        child: ConversationSurfaceV2(
          identity: identity,
          launchRequest: widget.launchRequest,
          onOpenThread: (message) => _openThread(context, message),
          onStartThread: (message) => _startThread(context, message),
          onForwardSelectionChanged: _handleForwardSelectionChanged,
        ),
      ),
    );
  }

  void _openThread(BuildContext context, ConversationMessageV2 message) {
    final threadRootId = message.serverMessageId;
    if (threadRootId == null) {
      return;
    }
    context.push(
      AppRoutes.nestedThreadDetail('${widget.chatId}', '$threadRootId'),
    );
  }

  void _startThread(BuildContext context, ConversationMessageV2 message) {
    final threadRootId = message.serverMessageId;
    if (threadRootId == null) {
      return;
    }
    context.push(
      AppRoutes.nestedNewThread('${widget.chatId}', '$threadRootId'),
    );
  }
}

class _ForwardSelectionCancelButton extends StatelessWidget {
  const _ForwardSelectionCancelButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Text(l10n.cancel),
    );
  }
}

class _ForwardSelectionTitle extends StatelessWidget {
  const _ForwardSelectionTitle({required this.selectedCount});

  final int selectedCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Text(l10n.forwardSelectedCount(selectedCount));
  }
}

class _ForwardSelectionForwardButton extends StatelessWidget {
  const _ForwardSelectionForwardButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      child: Text(l10n.forwardMessagesAction),
    );
  }
}

class _ChatDetailActions extends StatelessWidget {
  const _ChatDetailActions({required this.chatId});

  static const _buttonSize = Size.square(36);
  static const _iconSize = 26.0;

  final int chatId;

  @override
  Widget build(BuildContext context) {
    final routeChatId = chatId.toString();

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 0),
          minimumSize: _buttonSize,
          onPressed: () => context.push(AppRoutes.chatMembers(routeChatId)),
          child: const Icon(CupertinoIcons.person_2_fill, size: _iconSize),
        ),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 0),
          minimumSize: _buttonSize,
          onPressed: () => context.push(AppRoutes.chatSettings(routeChatId)),
          child: const Icon(CupertinoIcons.info_circle, size: _iconSize),
        ),
      ],
    );
  }
}

class _ChatDetailTitle extends ConsumerWidget {
  const _ChatDetailTitle({required this.chatId});

  final int chatId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final group = ref.watch(groupByIdProvider(chatId.toString()));
    final resolvedName = group?.name?.trim();
    final title = resolvedName != null && resolvedName.isNotEmpty
        ? resolvedName
        : 'Chat $chatId';
    return Text(title);
  }
}
