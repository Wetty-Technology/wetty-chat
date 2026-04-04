import 'package:flutter/cupertino.dart';

import '../../../app/theme/style_config.dart';
import '../../../core/session/dev_session_store.dart';

class DevSessionSettingsPage extends StatefulWidget {
  const DevSessionSettingsPage({super.key});

  @override
  State<DevSessionSettingsPage> createState() => _DevSessionSettingsPageState();
}

class _DevSessionSettingsPageState extends State<DevSessionSettingsPage> {
  late final TextEditingController _uidController;
  String? _errorText;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _uidController = TextEditingController(
      text: DevSessionStore.instance.currentUserId.toString(),
    );
  }

  @override
  void dispose() {
    _uidController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final raw = _uidController.text.trim();
    final nextUserId = int.tryParse(raw);
    if (nextUserId == null || nextUserId <= 0) {
      setState(() {
        _errorText = 'Enter a valid positive UID.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });
    try {
      await DevSessionStore.instance.setCurrentUserId(nextUserId);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _resetToDefault() async {
    setState(() {
      _isSaving = true;
      _errorText = null;
    });
    try {
      await DevSessionStore.instance.resetToDefault();
      _uidController.text = DevSessionStore.defaultUserId.toString();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = DevSessionStore.instance.currentUserId;
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Developer Session'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'The Flutter app currently uses a developer UID session. '
              'Changes apply immediately and reconnect realtime features.',
              style: appSecondaryTextStyle(
                context,
                fontSize: AppFontSizes.body,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Current UID',
              style: appTextStyle(
                context,
                fontSize: AppFontSizes.body,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$currentUserId',
              style: appTextStyle(
                context,
                fontSize: AppFontSizes.chatEntryTitle,
              ),
            ),
            const SizedBox(height: 24),
            CupertinoTextField(
              controller: _uidController,
              keyboardType: const TextInputType.numberWithOptions(
                signed: false,
                decimal: false,
              ),
              placeholder: 'Enter UID',
              padding: const EdgeInsets.all(14),
              onChanged: (_) {
                if (_errorText != null) {
                  setState(() {
                    _errorText = null;
                  });
                }
              },
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorText!,
                style: appTextStyle(
                  context,
                  fontSize: AppFontSizes.bodySmall,
                  color: CupertinoColors.systemRed.resolveFrom(context),
                ),
              ),
            ],
            const SizedBox(height: 16),
            CupertinoButton.filled(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const CupertinoActivityIndicator(
                      color: CupertinoColors.white,
                    )
                  : const Text('Save UID'),
            ),
            const SizedBox(height: 12),
            CupertinoButton(
              onPressed: _isSaving ? null : _resetToDefault,
              child: Text('Reset to UID ${DevSessionStore.defaultUserId}'),
            ),
          ],
        ),
      ),
    );
  }
}
