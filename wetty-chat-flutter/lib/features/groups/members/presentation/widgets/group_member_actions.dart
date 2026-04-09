import 'package:flutter/cupertino.dart';

import '../../data/group_member_models.dart';

class GroupMemberActions {
  const GroupMemberActions._();

  static Future<void> showErrorDialog(BuildContext context, String message) {
    return showCupertinoDialog<void>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static Future<bool> confirmAction(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    bool isDestructive = false,
  }) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: isDestructive,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  static Future<void> showMemberActions(
    BuildContext context, {
    required GroupMember member,
    required Future<void> Function() onToggleRole,
    required Future<void> Function() onRemoveMember,
  }) {
    return showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(context).pop();
              onToggleRole();
            },
            child: Text(
              member.role == 'admin' ? 'Demote to Member' : 'Promote to Admin',
            ),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.of(context).pop();
              onRemoveMember();
            },
            child: const Text('Remove from Group'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}
