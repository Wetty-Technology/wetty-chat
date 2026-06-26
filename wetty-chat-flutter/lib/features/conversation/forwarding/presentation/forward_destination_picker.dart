import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:chahua/app/theme/style_config.dart';
import 'package:chahua/features/chat_list/application/chat_list_v2_scope.dart';
import 'package:chahua/features/chat_list/application/group_list_v2_view_model.dart';
import 'package:chahua/features/chat_list/model/chat_list_item.dart';
import 'package:chahua/features/shared/presentation/app_avatar.dart';
import 'package:chahua/l10n/app_localizations.dart';

class ForwardDestinationPicker extends ConsumerWidget {
  const ForwardDestinationPicker({
    super.key,
    required this.sourceChatId,
    required this.onForward,
  });

  final int sourceChatId;
  final ValueChanged<int> onForward;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(
      groupListV2ViewModelProvider(ChatListV2Scope.active),
    );

    return asyncState.when(
      loading: () => const _ForwardDestinationPickerFrame(
        child: Center(child: CupertinoActivityIndicator()),
      ),
      error: (error, _) =>
          _ForwardDestinationPickerFrame(child: Center(child: Text('$error'))),
      data: (state) => ForwardDestinationPickerContent(
        sourceChatId: sourceChatId,
        groups: state.groups,
        onForward: onForward,
      ),
    );
  }
}

class ForwardDestinationPickerContent extends StatefulWidget {
  const ForwardDestinationPickerContent({
    super.key,
    required this.sourceChatId,
    required this.groups,
    required this.onForward,
  });

  final int sourceChatId;
  final List<ChatListItem> groups;
  final ValueChanged<int> onForward;

  @override
  State<ForwardDestinationPickerContent> createState() =>
      _ForwardDestinationPickerContentState();
}

class _ForwardDestinationPickerContentState
    extends State<ForwardDestinationPickerContent> {
  String? _selectedChatId;

  int? get _selectedDestinationChatId => int.tryParse(_selectedChatId ?? '');

  void _selectGroup(ChatListItem group) {
    if (_isSourceChat(group)) {
      return;
    }
    setState(() {
      _selectedChatId = group.id;
    });
  }

  void _forward() {
    final destinationChatId = _selectedDestinationChatId;
    if (destinationChatId == null) {
      return;
    }
    widget.onForward(destinationChatId);
  }

  bool _isSourceChat(ChatListItem group) {
    return group.id == widget.sourceChatId.toString();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return _ForwardDestinationPickerFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            title: l10n.forwardMessagesAction,
            canForward: _selectedDestinationChatId != null,
            onCancel: () => Navigator.pop(context),
            onForward: _forward,
          ),
          Container(height: 1, color: context.appColors.separator),
          Expanded(
            child: _GroupList(
              groups: widget.groups,
              sourceChatId: widget.sourceChatId,
              selectedChatId: _selectedChatId,
              onSelectGroup: _selectGroup,
            ),
          ),
        ],
      ),
    );
  }
}

class _ForwardDestinationPickerFrame extends StatelessWidget {
  const _ForwardDestinationPickerFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final borderRadius = const BorderRadius.vertical(top: Radius.circular(16));

    return ClipRRect(
      borderRadius: borderRadius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.backgroundSecondary,
          borderRadius: borderRadius,
          border: Border(top: BorderSide(color: colors.separator)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.9,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Center(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.separator,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: const SizedBox(width: 36, height: 4),
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.canForward,
    required this.onCancel,
    required this.onForward,
  });

  final String title;
  final bool canForward;
  final VoidCallback onCancel;
  final VoidCallback onForward;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              onPressed: onCancel,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(l10n.cancel),
              ),
            ),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: appTextStyle(
                context,
                fontSize: AppFontSizes.sectionTitle,
                fontWeight: AppFontWeights.semibold,
              ),
            ),
          ),
          SizedBox(
            width: 92,
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              onPressed: canForward ? onForward : null,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(l10n.forwardMessagesAction),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupList extends StatelessWidget {
  const _GroupList({
    required this.groups,
    required this.sourceChatId,
    required this.selectedChatId,
    required this.onSelectGroup,
  });

  final List<ChatListItem> groups;
  final int sourceChatId;
  final String? selectedChatId;
  final ValueChanged<ChatListItem> onSelectGroup;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (groups.isEmpty) {
      return Center(child: Text(l10n.noGroupsYet));
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: groups.length,
      separatorBuilder: (context, index) => Container(
        height: 1,
        margin: const EdgeInsets.only(left: 72),
        color: context.appColors.separator,
      ),
      itemBuilder: (context, index) {
        final group = groups[index];
        final isSourceChat = group.id == sourceChatId.toString();
        return _GroupRow(
          group: group,
          isCurrentChat: isSourceChat,
          isSelected: !isSourceChat && group.id == selectedChatId,
          onTap: isSourceChat ? null : () => onSelectGroup(group),
        );
      },
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.group,
    required this.isCurrentChat,
    required this.isSelected,
    required this.onTap,
  });

  final ChatListItem group;
  final bool isCurrentChat;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final name = group.name ?? '';

    return Opacity(
      opacity: isCurrentChat ? 0.48 : 1,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              AppAvatar(
                name: name,
                imageUrl: group.avatarUrl,
                size: 44,
                memCacheWidth: 96,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: appChatEntryTitleTextStyle(context),
                    ),
                    if (isCurrentChat)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          l10n.forwardCurrentChatLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: appMetaTextStyle(context),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isSelected
                    ? CupertinoIcons.checkmark_circle_fill
                    : CupertinoIcons.circle,
                size: 22,
                color: isSelected ? colors.accentPrimary : colors.inactive,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
