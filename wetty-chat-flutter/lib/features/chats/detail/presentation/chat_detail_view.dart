import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../../../app/theme/style_config.dart';
import '../../../../core/network/api_config.dart';
import '../../../../shared/presentation/app_divider.dart';
import '../../../groups/members/presentation/group_members_view.dart';
import '../../../groups/settings/presentation/group_settings_view.dart';
import '../../models/chat_input_state.dart';
import '../../models/message_models.dart';
import '../application/chat_detail_view_model.dart';
import '../data/attachment_service.dart';
import 'message_row.dart';

/// Chat detail screen: message list (oldest at top, newest at bottom) and send input.
class ChatDetailPage extends StatefulWidget {
  const ChatDetailPage({
    super.key,
    required this.chatId,
    required this.chatName,
    this.unreadCount = 0,
  });

  final String chatId;
  final String chatName;
  final int unreadCount;

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _PendingAttachment {
  final String id;
  final String name;
  final String mimeType;
  final Uint8List? previewBytes;

  _PendingAttachment({
    required this.id,
    required this.name,
    required this.mimeType,
    this.previewBytes,
  });

  bool get isImage => mimeType.startsWith('image/') && previewBytes != null;
}

class _ChatDetailPageState extends State<ChatDetailPage>
    with WidgetsBindingObserver {
  static const bool _isReversedMessageList = true;
  late final ChatDetailViewModel _viewModel;
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ScrollOffsetController _scrollOffsetController =
      ScrollOffsetController();
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  final ScrollController _inputScrollController = ScrollController();
  final TextEditingController _textController = TextEditingController();
  static const double _titleBarHeight = 70.0;
  bool _isPopping = false;
  final AttachmentService _attachmentService = AttachmentService();
  final List<_PendingAttachment> _pendingAttachments = [];
  bool _isUploadingAttachment = false;
  bool _isProgrammaticScrollActive = false;
  int _scrollOperationToken = 0;
  static const double _tallMessageHeightThreshold = 0.55;
  final GlobalKey _messageListKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _viewModel = ChatDetailViewModel(
      chatId: widget.chatId,
      unreadCount: widget.unreadCount,
    );
    WidgetsBinding.instance.addObserver(this);
    _viewModel.addListener(_onViewModelChanged);
    _itemPositionsListener.itemPositions.addListener(_onItemPositionsChanged);
    _viewModel.loadMessages();
    final draft = _viewModel.loadDraft();
    if (draft != null) _textController.text = draft;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveDraft();
    unawaited(_viewModel.flushReadStatus());
    _viewModel.removeListener(_onViewModelChanged);
    _viewModel.dispose();
    _itemPositionsListener.itemPositions.removeListener(
      _onItemPositionsChanged,
    );
    _inputScrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_viewModel.flushReadStatus());
    }
  }

  int? _lastJumpedId;

  /// registered via _viewModel.addListener(_onViewModelChanged);
  /// every time the view model calls notifyListeners(), this method will be called
  void _onViewModelChanged() {
    if (!mounted) return;

    // Check if we need to jump to the first unread message
    if (_viewModel.firstUnreadMessageId != null &&
        _viewModel.firstUnreadMessageId != _lastJumpedId) {
      _lastJumpedId = _viewModel.firstUnreadMessageId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _jumpToMessage(_lastJumpedId!);
      });
    }

    setState(() {});
  }

  void _saveDraft() {
    _viewModel.saveDraft(_textController.text);
  }

  Future<void> _popWithResult() async {
    if (_isPopping) return;
    _isPopping = true;
    _saveDraft();
    await _viewModel.flushReadStatus();
    if (!mounted) return;
    Navigator.pop(context, _viewModel.shouldRefreshChats);
  }

  void _onItemPositionsChanged() {
    if (_isProgrammaticScrollActive) {
      return;
    }
    if (_viewModel.isLoadingMore ||
        _viewModel.isLoading ||
        _viewModel.displayItems.isEmpty) {
      return;
    }

    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;

    // Show jump-to-bottom button when scrolled away from newest messages.
    // In reverse mode, index 0 is at the bottom.
    final isBottomVisible = positions.any((p) => p.index == 0);
    _viewModel.updateScrollToBottom(!isBottomVisible);

    final minIndex = positions
        .map((p) => p.index)
        .reduce((a, b) => a < b ? a : b);

    final maxIndex = positions
        .map((p) => p.index)
        .reduce((a, b) => a > b ? a : b);
    final totalCount =
        _viewModel.displayItems.length + (_viewModel.hasMoreMessages ? 1 : 0);

    if (maxIndex >= totalCount - 5) {
      _loadOlderMessages();
    }
    if (minIndex <= 4 && _viewModel.hasNewerMessages && !isBottomVisible) {
      _loadNewerMessages();
    }

    // Track read status
    for (final pos in positions) {
      // If at least 50% of the message is visible (simplified)
      if (pos.itemLeadingEdge < 0.9 && pos.itemTrailingEdge > 0.1) {
        final idx = pos.index;
        if (idx < _viewModel.displayItems.length) {
          final msg = _viewModel.displayItems[idx];
          _viewModel.onMessageVisible(msg.id);
        }
      }
    }
  }

  Future<void> _loadOlderMessages() async {
    final anchor = _topViewportAnchor();
    final changed = await _viewModel.loadMoreMessages();
    if (!changed || anchor == null || !mounted) return;

    await _runProgrammaticScroll((token) async {
      await _waitForNextFrame();
      if (!_canApplyScroll(token)) return;

      final anchorIndex = _viewModel.findWindowIndex(anchor.key);
      if (anchorIndex == null) return;
      _itemScrollController.jumpTo(
        index: anchorIndex,
        alignment: _safeAlignment(anchor.value),
      );
    });
  }

  void _clearAttachments() {
    if (_pendingAttachments.isEmpty) return;
    if (!mounted) {
      _pendingAttachments.clear();
      return;
    }
    setState(() {
      _pendingAttachments.clear();
    });
  }

  void _removeAttachmentAt(int index) {
    if (index < 0 || index >= _pendingAttachments.length) return;
    setState(() {
      _pendingAttachments.removeAt(index);
    });
  }

  String _guessContentType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.bmp')) return 'image/bmp';
    if (lower.endsWith('.heic')) return 'image/heic';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.json')) return 'application/json';
    if (lower.endsWith('.zip')) return 'application/zip';
    return 'application/octet-stream';
  }

  Future<void> _loadNewerMessages() async {
    final anchor = _bottomViewportAnchor();
    final changed = await _viewModel.loadNewerMessages();
    if (!changed || anchor == null || !mounted) return;

    await _runProgrammaticScroll((token) async {
      await _waitForNextFrame();
      if (!_canApplyScroll(token)) return;

      final anchorIndex = _viewModel.findWindowIndex(anchor.key);
      if (anchorIndex == null) return;
      _itemScrollController.jumpTo(
        index: anchorIndex,
        alignment: _safeAlignment(anchor.value),
      );
    });
  }

  Future<(int? width, int? height)> _decodeImageSize(Uint8List bytes) async {
    try {
      final completer = Completer<ui.Image>();
      ui.decodeImageFromList(bytes, (img) => completer.complete(img));
      final img = await completer.future.timeout(const Duration(seconds: 2));
      final size = (img.width, img.height);
      img.dispose();
      return size;
    } catch (_) {
      return (null, null);
    }
  }

  MapEntry<int, double>? _topViewportAnchor() {
    final positions = _itemPositionsListener.itemPositions.value
        .where((position) => position.index < _viewModel.displayItems.length)
        .toList();
    if (positions.isEmpty) return null;

    positions.sort((a, b) => b.index.compareTo(a.index));
    final anchor = positions.first;
    return MapEntry(
      _viewModel.displayItems[anchor.index].id,
      anchor.itemLeadingEdge,
    );
  }

  MapEntry<int, double>? _bottomViewportAnchor() {
    final positions = _itemPositionsListener.itemPositions.value
        .where((position) => position.index < _viewModel.displayItems.length)
        .toList();
    if (positions.isEmpty) return null;

    positions.sort((a, b) => a.index.compareTo(b.index));
    final anchor = positions.first;
    return MapEntry(
      _viewModel.displayItems[anchor.index].id,
      anchor.itemLeadingEdge,
    );
  }

  Future<void> _scrollToBottom() async {
    await _runProgrammaticScroll((token) async {
      await _viewModel.jumpToBottom();
      if (!_canApplyScroll(token) || _viewModel.displayItems.isEmpty) return;

      await _waitForNextFrame();
      if (!_canApplyScroll(token)) return;

      _itemScrollController.jumpTo(index: 0, alignment: 0);
      await Future<void>.delayed(const Duration(milliseconds: 16));
      if (!_canApplyScroll(token)) return;

      await _itemScrollController.scrollTo(
        index: 0,
        alignment: 0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  bool _canApplyScroll(int token) =>
      mounted && token == _scrollOperationToken && _itemScrollController.isAttached;

  double _safeAlignment(double alignment) {
    return alignment.clamp(0.0, 1.0).toDouble();
  }

  double _messageJumpAlignment(ItemPosition position) {
    final height = position.itemTrailingEdge - position.itemLeadingEdge;
    if (height >= _tallMessageHeightThreshold) {
      return _safeAlignment(0.5);
    }

    return _safeAlignment(0.5 - height);
  }

  bool _isTallMessage(ItemPosition position) {
    final height = position.itemTrailingEdge - position.itemLeadingEdge;
    return height >= _tallMessageHeightThreshold;
  }

  double _messageStartEdge(ItemPosition position) {
    return _isReversedMessageList
        ? position.itemTrailingEdge
        : position.itemLeadingEdge;
  }

  Future<void> _adjustTallMessagePosition(
    int targetIdx, {
    required int token,
  }) async {
    final viewportHeight = _messageListKey.currentContext?.size?.height;
    if (viewportHeight == null || viewportHeight <= 0) return;

    final positions = _itemPositionsListener.itemPositions.value;
    final targetPos = positions.where((p) => p.index == targetIdx).toList();
    if (targetPos.isEmpty) return;

    final pos = targetPos.first;
    if (!_isTallMessage(pos)) return;

    final deltaPixels = (_messageStartEdge(pos) - 0.5) * viewportHeight;
    if (deltaPixels.abs() < 1 || !_canApplyScroll(token)) return;

    await _scrollOffsetController.animateScroll(
      offset: deltaPixels,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _waitForNextFrame() {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    return completer.future;
  }

  Future<void> _runProgrammaticScroll(
    Future<void> Function(int token) operation,
  ) async {
    final token = ++_scrollOperationToken;
    _isProgrammaticScrollActive = true;
    try {
      await operation(token);
    } finally {
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (mounted && token == _scrollOperationToken) {
        _isProgrammaticScrollActive = false;
      }
    }
  }

  void _clearInputMessage() {
    _textController.clear();
    _viewModel.clearInputState();
  }

  Future<void> _pickAttachment() async {
    if (kIsWeb || !Platform.isWindows) {
      _showErrorDialog('目前只实现了 Windows 上传逻辑');
      return;
    }
    if (_isUploadingAttachment) return;

    final file = await openFile();
    if (file == null) return;

    setState(() {
      _isUploadingAttachment = true;
    });

    try {
      final filename = file.name;
      final contentType = _guessContentType(filename);
      final size = await file.length();

      Uint8List? previewBytes;
      int? width;
      int? height;

      if (contentType.startsWith('image/')) {
        final shouldPreview = size <= 8 * 1024 * 1024;
        if (shouldPreview) {
          previewBytes = await file.readAsBytes();
          final dims = await _decodeImageSize(previewBytes);
          width = dims.$1;
          height = dims.$2;
        }
      }

      final uploadInfo = await _attachmentService.requestUploadUrl(
        filename: filename,
        contentType: contentType,
        size: size,
        width: width,
        height: height,
      );

      await _attachmentService.uploadFileToS3(
        uploadUrl: uploadInfo.uploadUrl,
        file: File(file.path),
        contentType: contentType,
      );

      if (!mounted) return;
      setState(() {
        _pendingAttachments.add(
          _PendingAttachment(
            id: uploadInfo.attachmentId,
            name: filename,
            mimeType: contentType,
            previewBytes: previewBytes,
          ),
        );
      });
    } catch (e) {
      if (mounted) _showErrorDialog('上传失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingAttachment = false;
        });
      }
    }
  }

  Widget _buildAttachmentPreview(BuildContext context) {
    if (_pendingAttachments.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (int i = 0; i < _pendingAttachments.length; i++)
            _buildAttachmentChip(context, _pendingAttachments[i], i),
        ],
      ),
    );
  }

  Widget _buildAttachmentChip(
    BuildContext context,
    _PendingAttachment attachment,
    int index,
  ) {
    final borderColor = CupertinoColors.systemGrey4.resolveFrom(context);
    final bgColor = CupertinoColors.systemGrey5.resolveFrom(context);
    final textColor = CupertinoColors.label.resolveFrom(context);

    final thumb = attachment.isImage
        ? ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.memory(
              attachment.previewBytes!,
              width: 36,
              height: 36,
              fit: BoxFit.cover,
            ),
          )
        : Icon(
            CupertinoIcons.doc,
            size: 28,
            color: CupertinoColors.activeBlue.resolveFrom(context),
          );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          thumb,
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(
              attachment.name,
              overflow: TextOverflow.ellipsis,
              style: appTextStyle(
                context,
                fontSize: AppFontSizes.meta,
                color: textColor,
              ),
            ),
          ),
          const SizedBox(width: 6),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(20, 20),
            onPressed: () => _removeAttachmentAt(index),
            child: Icon(
              CupertinoIcons.xmark_circle_fill,
              size: 18,
              color: CupertinoColors.systemGrey2.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    final attachmentIds = _pendingAttachments.map((a) => a.id).toList();
    final hasAttachments = attachmentIds.isNotEmpty;
    if (text.isEmpty && !hasAttachments) return;
    if (_isUploadingAttachment) {
      _showErrorDialog('文件正在上传，请稍后再发送');
      return;
    }

    switch (_viewModel.inputState) {
      case InputEditing(:final message):
        if (hasAttachments) {
          _showErrorDialog('编辑消息暂不支持附件');
          return;
        }
        if (text == message.message) return;
        try {
          await _viewModel.editMessage(message.id, text);
          if (!mounted) return;
          _clearInputMessage();
        } catch (e) {
          if (mounted) _showErrorDialog('$e');
        }

      case InputReplying(:final message):
        _clearInputMessage();
        _viewModel.clearDraft();
        try {
          await _viewModel.sendMessage(
            text,
            replyToId: message.id,
            attachmentIds: attachmentIds,
          );
          _clearAttachments();
          _scrollToBottom();
        } catch (e) {
          if (mounted) _showErrorDialog('$e');
        }

      case InputEmpty():
        _clearInputMessage();
        _viewModel.clearDraft();
        try {
          await _viewModel.sendMessage(text, attachmentIds: attachmentIds);
          _clearAttachments();
          _scrollToBottom();
        } catch (e) {
          if (mounted) _showErrorDialog('$e');
        }
    }
  }

  Future<void> _jumpToMessage(int messageId) async {
    await _runProgrammaticScroll((token) async {
      final found = await _viewModel.jumpToMessage(messageId);
      if (!found || !_canApplyScroll(token)) return;

      final idx = _viewModel.findWindowIndex(messageId);
      if (idx == null) return;

      Future<void> performRefinedScroll(int targetIdx) async {
        final positions = _itemPositionsListener.itemPositions.value;
        final targetPos = positions.where((p) => p.index == targetIdx).toList();
        if (targetPos.isEmpty) return;

        final pos = targetPos.first;
        if (_isTallMessage(pos)) {
          await _adjustTallMessagePosition(targetIdx, token: token);
          return;
        }

        await _itemScrollController.scrollTo(
          index: targetIdx,
          alignment: _messageJumpAlignment(pos),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }

      final currentVisible = _itemPositionsListener.itemPositions.value
          .where((p) => p.index == idx)
          .toList();
      if (currentVisible.isNotEmpty) {
        await performRefinedScroll(idx);
        return;
      }

      await _waitForNextFrame();
      if (!_canApplyScroll(token)) return;

      final idx2 = _viewModel.findWindowIndex(messageId);
      if (idx2 == null) return;

      _itemScrollController.jumpTo(index: idx2, alignment: 0.5);

      await Future<void>.delayed(Duration.zero);
      if (!_canApplyScroll(token)) return;

      var positions = _itemPositionsListener.itemPositions.value
          .where((pos) => pos.index == idx2)
          .toList();

      if (positions.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 16));
        if (!_canApplyScroll(token)) return;
        positions = _itemPositionsListener.itemPositions.value
            .where((pos) => pos.index == idx2)
            .toList();
      }

      if (positions.isNotEmpty) {
        await performRefinedScroll(idx2);
        return;
      }

      await _itemScrollController.scrollTo(
        index: idx2,
        alignment: 0.5,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _showErrorDialog(String message) {
    showCupertinoDialog(
      context: context,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showMessageActions(MessageItem msg) {
    if (msg.isDeleted) return;
    final currentUserId = ApiSession.currentUserId;
    final isOwn = currentUserId != null && msg.sender.uid == currentUserId;

    showCupertinoModalPopup(
      context: context,
      builder: (_) => CupertinoActionSheet(
        actions: [
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(context);
              _viewModel.setReplyTo(msg);
            },
            child: const Text('Reply'),
          ),
          if (isOwn)
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _clearAttachments();
                _viewModel.startEditing(msg);
                _textController.text = msg.message ?? '';
              },
              child: const Text('Edit'),
            ),
          if (isOwn)
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(context);
                _confirmDelete(msg);
              },
              child: const Text('Delete'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }

  void _confirmDelete(MessageItem msg) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Delete message?'),
        content: const Text('This cannot be undone.'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _viewModel.deleteMessage(msg.id);
              } catch (e) {
                if (mounted) _showErrorDialog('$e');
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chatName = widget.chatName.isEmpty
        ? 'Chat ${widget.chatId}'
        : widget.chatName;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          unawaited(_popWithResult());
        }
      },
      child: CupertinoPageScaffold(
        backgroundColor: const Color(0xFFECE5DD),
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Stack(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: Stack(
                        children: [
                          _buildBody(),
                          if (_viewModel.showScrollToBottom)
                            Positioned(
                              right: 16,
                              bottom: 16,
                              child: CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: _scrollToBottom,
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.systemGrey5
                                        .resolveFrom(context),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    CupertinoIcons.chevron_down,
                                    size: 20,
                                    color: CupertinoColors.label.resolveFrom(
                                      context,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: _buildInput(),
                    ),
                  ],
                ),
              ),
              // Gradient title bar overlay
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(0, 0.5),
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFECE5DD),
                        Color(0xDFECE5DD),
                        Color(0xCCECE5DD),
                        Color(0x80ECE5DD),
                        Color(0x40ECE5DD),
                        Color(0x00ECE5DD),
                      ],
                      stops: [0.0, 0.5, 0.6, 0.8, 0.9, 1.0],
                    ),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: SizedBox(
                      height: _titleBarHeight,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 36),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Text(
                              chatName,
                              textAlign: TextAlign.center,
                              style: appTitleTextStyle(
                                context,
                                fontSize: AppFontSizes.appTitle,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Positioned(
                              left: 8,
                              child: CupertinoButton(
                                padding: EdgeInsets.zero,
                                onPressed: _popWithResult,
                                child: const Icon(
                                  CupertinoIcons.back,
                                  size: 28,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 8,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () => Navigator.push(
                                      context,
                                      CupertinoPageRoute(
                                        builder: (_) => GroupMembersPage(
                                          chatId: widget.chatId,
                                        ),
                                      ),
                                    ),
                                    child: const Icon(
                                      CupertinoIcons.person_2_fill,
                                      size: 22,
                                    ),
                                  ),
                                  CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () => Navigator.push(
                                      context,
                                      CupertinoPageRoute(
                                        builder: (_) => GroupSettingsPage(
                                          chatId: widget.chatId,
                                          currentName: widget.chatName,
                                        ),
                                      ),
                                    ),
                                    child: const Icon(
                                      CupertinoIcons.gear_solid,
                                      size: IconSizes.iconSize,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_viewModel.isLoading) {
      return const Center(child: CupertinoActivityIndicator());
    }
    if (_viewModel.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(_viewModel.errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              CupertinoButton.filled(
                onPressed: _viewModel.loadMessages,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_viewModel.displayItems.isEmpty) {
      return const Center(child: Text('No messages yet'));
    }
    final showTopLoader =
        _viewModel.hasMoreMessages && _viewModel.isLoadingMore;
    final items = _viewModel.displayItems;
    final itemCount = items.length + (showTopLoader ? 1 : 0);

    return ScrollablePositionedList.builder(
      key: _messageListKey,
      itemScrollController: _itemScrollController,
      scrollOffsetController: _scrollOffsetController,
      itemPositionsListener: _itemPositionsListener,
      reverse: true,
      padding: const EdgeInsets.only(top: _titleBarHeight),
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (showTopLoader && index == itemCount - 1) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CupertinoActivityIndicator()),
          );
        }

        final msg = items[index];
        final isHighlighted = _viewModel.highlightedMessageId == msg.id;

        bool showSenderName = true;
        if (index < items.length - 1) {
          final next = items[index + 1];
          if (next.sender.uid == msg.sender.uid) {
            showSenderName = false;
          }
        }

        bool showAvatar = true;
        if (index > 0) {
          final prev = items[index - 1];
          if (prev.sender.uid == msg.sender.uid) {
            showAvatar = false;
          }
        }

        final isFirstUnread =
            _viewModel.firstUnreadMessageId == msg.id &&
            _viewModel.showUnreadDivider;

        final messageRow = MessageRow(
          key: ValueKey(msg.id),
          message: msg,
          isHighlighted: isHighlighted,
          onLongPress: () => _showMessageActions(msg),
          onReply: () => _viewModel.setReplyTo(msg),
          onTapReply: msg.replyToMessage != null
              ? () => _jumpToMessage(msg.replyToMessage!.id)
              : null,
          showSenderName: showSenderName,
          showAvatar: showAvatar,
        );

        if (isFirstUnread) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [_buildUnreadDivider(), messageRow],
          );
        }

        return messageRow;
      },
    );
  }

  Widget _buildUnreadDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(child: AppDivider(color: CupertinoColors.systemGrey4)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: CupertinoColors.systemGrey4.resolveFrom(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Unread Messages',
              style: appOnDarkTextStyle(
                context,
                fontSize: AppFontSizes.meta,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Expanded(child: AppDivider(color: CupertinoColors.systemGrey4)),
        ],
      ),
    );
  }

  Widget _buildInput() {
    final hasPreview = _viewModel.inputState is! InputEmpty;
    final isEditing = _viewModel.inputState is InputEditing;
    final canAttach = !_isUploadingAttachment && !isEditing;

    return Column(
      children: [
        const AppDivider(height: 0.5, color: CupertinoColors.separator),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: canAttach ? _pickAttachment : null,
                    child: Icon(
                      CupertinoIcons.add_circled,
                      color: canAttach
                          ? CupertinoColors.activeBlue.resolveFrom(context)
                          : CupertinoColors.systemGrey2.resolveFrom(context),
                      size: 28,
                    ),
                  ),
                  if (_isUploadingAttachment)
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 2),
                      child: CupertinoActivityIndicator(radius: 8),
                    ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemBackground.resolveFrom(
                          context,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: CupertinoColors.systemGrey4.resolveFrom(
                            context,
                          ),
                          width: 1.0,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          switch (_viewModel.inputState) {
                            InputReplying(:final message) => _replyToMsg(
                              title:
                                  'Replying to ${message.sender.name ?? 'User ${message.sender.uid}'}',
                              body: message.message ?? '',
                            ),
                            InputEditing(:final message) => _buildPreviewBar(
                              title: 'Edit Message',
                              body: message.message ?? '',
                            ),
                            InputEmpty() => const SizedBox.shrink(),
                          },
                          if (hasPreview)
                            Container(
                              height: 0.5,
                              color: CupertinoColors.separator.resolveFrom(
                                context,
                              ),
                            ),
                          _buildAttachmentPreview(context),
                          CupertinoScrollbar(
                            controller: _inputScrollController,
                            child: CupertinoTextField(
                              controller: _textController,
                              scrollController: _inputScrollController,
                              placeholder: 'Message',
                              maxLines: 5,
                              minLines: 1,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: CupertinoColors.activeBlue,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.paperplane_fill,
                        size: 20,
                        color: CupertinoColors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _replyToMsg({required String title, required String body}) {
    _textController.clear();
    return _buildPreviewBar(title: title, body: body);
  }

  Widget _buildPreviewBar({required String title, required String body}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      decoration: BoxDecoration(
        color: CupertinoColors.systemGrey5.resolveFrom(context),
        border: const Border(
          left: BorderSide(color: CupertinoColors.activeBlue, width: 3),
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: appTextStyle(
                    context,
                    fontWeight: FontWeight.w600,
                    fontSize: AppFontSizes.bodySmall,
                    color: CupertinoColors.activeBlue,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: appSecondaryTextStyle(
                    context,
                    fontSize: AppFontSizes.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          CupertinoButton(
            padding: EdgeInsets.zero,
            minimumSize: const Size(30, 30),
            onPressed: _clearInputMessage,
            child: Icon(
              CupertinoIcons.xmark_circle_fill,
              size: 20,
              color: CupertinoColors.systemGrey3.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }
}
