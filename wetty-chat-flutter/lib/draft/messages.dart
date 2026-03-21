// import 'dart:async';

// import 'package:flutter/cupertino.dart';
// import 'package:flutter/gestures.dart';
// import 'package:flutter_application_1/draft/widgets.dart';
// import 'package:http/http.dart' as http;
// import 'package:url_launcher/url_launcher.dart';
// import 'dart:convert';

// import '../api_config.dart';
// import 'draft_store.dart';
// import 'group_members.dart';
// import 'group_settings.dart';
// import 'models.dart';

// // ---------------------------------------------------------------------------
// // Message store with sorted ranges
// // ---------------------------------------------------------------------------

// class MessageRange {
//   BigInt start; // Oldest message ID
//   BigInt end; // Newest message ID
//   final List<MessageItem> messages = []; // Sorted newest→oldest (desc by ID)

//   MessageRange({required this.start, required this.end});

//   // /// Binary-search insert: keeps descending order, skips duplicates.
//   // bool insertSorted(MessageItem msg) {
//   //   int lo = 0, hi = messages.length;
//   //   while (lo < hi) {
//   //     final mid = (lo + hi) >> 1;
//   //     final c = cmp(messages[mid].id, msg.id);
//   //     if (c == 0) return false; // duplicate
//   //     if (c > 0) {
//   //       lo = mid + 1; // messages[mid] is newer → go right
//   //     } else {
//   //       hi = mid; // messages[mid] is older → go left
//   //     }
//   //   }
//   //   messages.insert(lo, msg);
//   //   _updateBounds();
//   //   return true;
//   // }

//   // /// Bulk insert.
//   // void insertAll(List<MessageItem> items) {
//   //   for (final m in items) {
//   //     insertSorted(m);
//   //   }
//   // }

//   // void _updateBounds() {
//   //   if (messages.isEmpty) return;
//   //   start = messages.last.id; // oldest
//   //   end = messages.first.id; // newest
//   // }
// }

// class MessageStore {
//   // ranges will be inserted in order
//   final List<MessageRange> messageRanges = [];

//   // Add a batch of messages from fetching: find overlapping ranges, merge them.
//   void addMessages(List<MessageItem> items) {
//     if (items.isEmpty) return;

//     // Sort newest→oldest (descending by ID as BigInt)
//     items.sort((a, b) {
//       return BigInt.parse(b.id).compareTo(BigInt.parse(a.id));
//     });

//     // new message range
//     final newest = BigInt.parse(items.first.id);
//     final oldest = BigInt.parse(items.last.id);
//     final range = MessageRange(start: oldest, end: newest);

//     // TODO: change this when have overlaped ranges
//     range.messages.addAll(items);
//     // Binary-search insert to keep ranges sorted desc by end
//     int lo = 0, hi = messageRanges.length;
//     while (lo < hi) {
//       final mid = (lo + hi) >> 1;
//       if (messageRanges[mid].end.compareTo(newest) > 0) {
//         lo = mid + 1;
//       } else {
//         hi = mid;
//       }
//     }
//     messageRanges.insert(lo, range);

//     // // Find all existing ranges that overlap with [oldest, newest]
//     // final overlapping = <int>[];
//     // for (int i = 0; i < ranges.length; i++) {
//     //   final r = ranges[i];
//     //   // Overlap if: newOldest <= rangeNewest AND newNewest >= rangeOldest
//     //   if (MessageRange.cmp(oldest, r.end) <= 0 &&
//     //       MessageRange.cmp(newest, r.start) >= 0) {
//     //     overlapping.add(i);
//     //   }
//     // }

//     // if (overlapping.isEmpty) {
//     //   // No overlap — create a new range
//     //   final range = MessageRange(start: oldest, end: newest);
//     //   range.insertAll(items);
//     //   ranges.add(range);
//     // } else {
//     //   // Merge: pick the first overlapping range as target, absorb others + new items
//     //   final targetIdx = overlapping.first;
//     //   final target = ranges[targetIdx];

//     //   // Absorb messages from all other overlapping ranges
//     //   for (int i = overlapping.length - 1; i >= 1; i--) {
//     //     final otherIdx = overlapping[i];
//     //     target.insertAll(ranges[otherIdx].messages);
//     //     ranges.removeAt(otherIdx);
//     //   }

//     //   // Insert the new items
//     //   target.insertAll(items);
//     // }

//     // // Keep ranges sorted desc by end
//     // ranges.sort((a, b) => MessageRange.cmp(b.end, a.end));
//   }

//   /// Flatten all sorted ranges into one list (newest→oldest).
//   List<MessageItem> buildDisplayItems() {
//     // Put all messages together
//     final all = <MessageItem>[];
//     for (final r in messageRanges) {
//       all.addAll(r.messages);
//     }
//     // all.sort((a, b) => MessageRange.cmp(b.id, a.id)); // desc
//     all.sort((a, b) => b.id.compareTo(a.id));
//     return all;
//   }

//   void clear() {
//     messageRanges.clear();
//   }

//   /// Remove a message by ID from whichever range contains it.
//   void removeById(String id) {
//     // TODO: can use binary search to remove
//     for (final r in messageRanges) {
//       final removed = r.messages.where((m) => m.id == id).isNotEmpty;
//       if (removed) {
//         r.messages.removeWhere((m) => m.id == id);
//         break;
//       }
//     }
//   }

//   /// Find and replace a message across all ranges.
//   void replaceWhere(bool Function(MessageItem) test, MessageItem replacement) {
//     for (final r in messageRanges) {
//       final idx = r.messages.indexWhere(test);
//       if (idx >= 0) {
//         r.messages[idx] = replacement;
//         return;
//       }
//     }
//   }

//   /// Remove messages matching a test from all ranges.
//   void removeWhere(bool Function(MessageItem) test) {
//     for (final r in messageRanges) {
//       r.messages.removeWhere(test);
//     }
//   }

//   bool get isEmpty =>
//       messageRanges.isEmpty || messageRanges.every((r) => r.messages.isEmpty);
//   bool get isNotEmpty => !isEmpty;

//   /// Oldest loaded ID (for "load more" before param).
//   String? get oldestId =>
//       messageRanges.isNotEmpty ? messageRanges.last.start.toString() : null;

//   /// Insert a single message into the newest range (for optimistic send).
//   /// Temp messages are always the newest, so insert at front.
//   // void insertIntoNewestRange(MessageItem msg) {
//   //   if (messageRanges.isNotEmpty) {
//   //     messageRanges.first.messages.insert(0, msg);
//   //   } else {
//   //     final range = MessageRange(
//   //       start: BigInt.parse(msg.id),
//   //       end: BigInt.parse(msg.id),
//   //     );
//   //     range.messages.add(msg);
//   //     messageRanges.add(range);
//   //   }
//   // }
// }

// // ---------------------------------------------------------------------------
// // API functions
// // ---------------------------------------------------------------------------

// Future<ListMessagesResponse> fetchMessages(
//   String chatId, {
//   int? max,
//   String? before,
//   String? after,
// }) async {
//   final query = <String, String>{};
//   if (max != null) query['max'] = max.toString();
//   if (before != null && before.isNotEmpty) query['before'] = before;
//   if (after != null && after.isNotEmpty) query['after'] = after;
//   final uri = Uri.parse(
//     '$apiBaseUrl/chats/$chatId/messages',
//   ).replace(queryParameters: query.isEmpty ? null : query);
//   final response = await http.get(uri, headers: apiHeaders);
//   if (response.statusCode != 200) {
//     throw Exception(
//       'Failed to load messages: ${response.statusCode} ${response.body}',
//     );
//   }
//   final res = ListMessagesResponse.fromJson(
//     jsonDecode(response.body) as Map<String, dynamic>,
//   );
//   return res;
// }

// /// Fetches messages around [messageId] for deep linking.
// Future<List<MessageItem>> fetchAround(String chatId, String messageId) async {
//   final resBefore = await fetchMessages(chatId, max: 15, before: messageId);
//   final resAfter = await fetchMessages(chatId, max: 15, after: messageId);
//   return [...resBefore.messages, ...resAfter.messages];
// }

// Future<MessageItem> sendMessage(
//   String chatId,
//   String text, {
//   String? replyToId,
// }) async {
//   final uri = Uri.parse('$apiBaseUrl/chats/$chatId/messages');
//   final clientGeneratedId =
//       '${DateTime.now().millisecondsSinceEpoch}-${Uri.base.hashCode}';
//   final body = <String, dynamic>{
//     'message': text,
//     'message_type': 'text',
//     'client_generated_id': clientGeneratedId,
//   };
//   if (replyToId != null) body['reply_to_id'] = int.parse(replyToId);
//   final response = await http.post(
//     uri,
//     headers: apiHeaders,
//     body: jsonEncode(body),
//   );
//   if (response.statusCode != 201) {
//     throw Exception(
//       'Failed to send message: ${response.statusCode} ${response.body}',
//     );
//   }
//   return MessageItem.fromJson(
//     jsonDecode(response.body) as Map<String, dynamic>,
//   );
// }

// Future<MessageItem> editMessage(
//   String chatId,
//   String messageId,
//   String newText,
// ) async {
//   final uri = Uri.parse('$apiBaseUrl/chats/$chatId/messages/$messageId');
//   final response = await http.patch(
//     uri,
//     headers: apiHeaders,
//     body: jsonEncode({'message': newText}),
//   );
//   if (response.statusCode != 200) {
//     throw Exception(
//       'Failed to edit message: ${response.statusCode} ${response.body}',
//     );
//   }
//   return MessageItem.fromJson(
//     jsonDecode(response.body) as Map<String, dynamic>,
//   );
// }

// Future<void> deleteMessage(String chatId, String messageId) async {
//   final uri = Uri.parse('$apiBaseUrl/chats/$chatId/messages/$messageId');
//   final response = await http.delete(uri, headers: apiHeaders);
//   if (response.statusCode != 204) {
//     throw Exception(
//       'Failed to delete message: ${response.statusCode} ${response.body}',
//     );
//   }
// }

// // ---------------------------------------------------------------------------
// // InputState – the three mutually exclusive states for the input bar
// // ---------------------------------------------------------------------------

// sealed class InputState {}

// class InputEmpty extends InputState {}

// class InputReplying extends InputState {
//   final MessageItem message;
//   InputReplying(this.message);
// }

// class InputEditing extends InputState {
//   final MessageItem message;
//   InputEditing(this.message);
// }

// // ---------------------------------------------------------------------------
// // ChatDetailPage
// // ---------------------------------------------------------------------------

// /// Chat detail screen: message list (oldest at top, newest at bottom) and send input.
// /// Scroll up loads older messages via [nextCursor] / before cursor.
// class ChatDetailPage extends StatefulWidget {
//   const ChatDetailPage({
//     super.key,
//     required this.chatId,
//     required this.chatName,
//   });

//   final String chatId;
//   final String chatName;

//   @override
//   State<ChatDetailPage> createState() => _ChatDetailPageState();
// }

// class _ChatDetailPageState extends State<ChatDetailPage> {
//   final MessageStore _store = MessageStore();
//   List<MessageItem> _displayItems = [];
//   bool _isLoading = true;
//   bool _isLoadingMore = false;
//   String? _errorMessage;
//   bool _showScrollToBottom = false;
//   InputState _inputState = InputEmpty();
//   String? _highlightedMessageId;
//   String? _nextCursor; // For "load more" at the top
//   late ScrollController _scrollController;
//   final ScrollController _inputScrollController = ScrollController();
//   final TextEditingController _textController = TextEditingController();
//   static const double _titleBarHeight = 70.0;

//   void _rebuildDisplay() {
//     setState(() {
//       _displayItems = _store.buildDisplayItems();
//     });
//   }

//   // ---- Lifecycle ----

//   @override
//   void initState() {
//     super.initState();
//     _scrollController = ScrollController()..addListener(_onScroll);
//     _loadMessages();
//     final draft = DraftStore.instance.getDraft(widget.chatId);
//     if (draft != null) _textController.text = draft;
//   }

//   @override
//   void dispose() {
//     _saveDraft();
//     _scrollController.removeListener(_onScroll);
//     _scrollController.dispose();
//     _inputScrollController.dispose();
//     _textController.dispose();
//     super.dispose();
//   }

//   void _saveDraft() {
//     final text = _textController.text.trim();
//     if (text.isNotEmpty) {
//       DraftStore.instance.setDraft(widget.chatId, text);
//     } else {
//       DraftStore.instance.clearDraft(widget.chatId);
//     }
//   }

//   void _onScroll() {
//     final pos = _scrollController.position;
//     // Show jump-to-bottom button when scrolled away from newest messages.
//     final shouldShow = pos.pixels > 300;
//     if (shouldShow != _showScrollToBottom) {
//       setState(() => _showScrollToBottom = shouldShow);
//     }
//     if (_isLoadingMore || _isLoading || _displayItems.isEmpty) return;
//     if (pos.pixels >= pos.maxScrollExtent - 200) {
//       _loadMoreMessages();
//     }
//   }

//   void _scrollToBottom() {
//     if (!_scrollController.hasClients) return;
//     _scrollController.animateTo(
//       0,
//       duration: const Duration(milliseconds: 300),
//       curve: Curves.easeOut,
//     );
//   }

//   Future<void> _loadMessages() async {
//     if (!mounted) return;
//     setState(() {
//       _isLoading = true;
//       _errorMessage = null;
//     });
//     try {
//       final res = await fetchMessages(widget.chatId);
//       if (!mounted) return;
//       _store.clear();
//       _store.addMessages(res.messages);
//       _nextCursor = res.nextCursor;
//       setState(() {
//         _isLoading = false;
//         _errorMessage = null;
//       });
//       _rebuildDisplay();
//     } catch (e) {
//       if (!mounted) return;
//       setState(() {
//         _isLoading = false;
//         _errorMessage = e.toString();
//       });
//     }
//   }

//   Future<void> _loadMoreMessages() async {
//     if (_store.isEmpty || _isLoadingMore || _nextCursor == null) return;

//     setState(() => _isLoadingMore = true);
//     try {
//       final res = await fetchMessages(widget.chatId, before: _store.oldestId);
//       if (!mounted) return;
//       _store.addMessages(res.messages);
//       _nextCursor = res.nextCursor;
//       setState(() => _isLoadingMore = false);
//       _rebuildDisplay();
//     } catch (e) {
//       if (!mounted) return;
//       setState(() => _isLoadingMore = false);
//     }
//   }

//   void _setReplyTo(MessageItem msg) {
//     setState(() => _inputState = InputReplying(msg));
//   }

//   void _clearInputMessage() {
//     _textController.clear();
//     setState(() => _inputState = InputEmpty());
//   }

//   void _startEditing(MessageItem msg) {
//     setState(() {
//       _inputState = InputEditing(msg);
//       _textController.text = msg.message ?? '';
//     });
//   }

//   Future<void> _jumpToMessage(String messageId) async {
//     int idx = _displayItems.indexWhere((m) => m.id == messageId);
//     if (idx < 0) {
//       setState(() => _isLoadingMore = true);
//       try {
//         final msgs = await fetchAround(widget.chatId, messageId);
//         if (!mounted) return;
//         _store.addMessages(msgs);
//         _rebuildDisplay();
//         setState(() => _isLoadingMore = false);
//         idx = _displayItems.indexWhere((m) => m.id == messageId);
//       } catch (e) {
//         if (mounted) {
//           setState(() => _isLoadingMore = false);
//           _showErrorDialog('Failed to jump: $e');
//         }
//         return;
//       }
//     }
//     if (idx < 0) return;

//     _scrollController.animateTo(
//       idx * 80.0,
//       duration: const Duration(milliseconds: 300),
//       curve: Curves.easeOut,
//     );
//     setState(() => _highlightedMessageId = messageId);
//     Future.delayed(const Duration(milliseconds: 2000), () {
//       if (mounted) setState(() => _highlightedMessageId = null);
//     });
//   }

//   Future<void> _sendMessage() async {
//     final text = _textController.text.trim();
//     if (text.isEmpty) return;

//     switch (_inputState) {
//       case InputEditing(:final message):
//         if (text == message.message) return;
//         try {
//           final updated = await editMessage(widget.chatId, message.id, text);
//           if (!mounted) return;
//           _store.replaceWhere((m) => m.id == message.id, updated);
//           _rebuildDisplay();
//           _clearInputMessage();
//         } catch (e) {
//           if (mounted) _showErrorDialog('Failed to edit: $e');
//         }

//       case InputReplying(:final message):
//         _clearInputMessage();
//         DraftStore.instance.clearDraft(widget.chatId);
//         try {
//           final res = await sendMessage(
//             widget.chatId,
//             text,
//             replyToId: message.id,
//           );
//           if (!mounted) return;
//           _store.addMessages([res]);
//           _rebuildDisplay();
//         } catch (e) {
//           if (mounted) _showErrorDialog('Failed to send: $e');
//         }

//       case InputEmpty():
//         _clearInputMessage();
//         DraftStore.instance.clearDraft(widget.chatId);
//         try {
//           final res = await sendMessage(widget.chatId, text);
//           if (!mounted) return;
//           _store.addMessages([res]);
//           _rebuildDisplay();
//         } catch (e) {
//           if (mounted) _showErrorDialog('Failed to send: $e');
//         }
//     }
//   }

//   void _showErrorDialog(String message) {
//     showCupertinoDialog(
//       context: context,
//       builder: (_) => CupertinoAlertDialog(
//         title: const Text('Error'),
//         content: Text(message),
//         actions: [
//           CupertinoDialogAction(
//             isDefaultAction: true,
//             onPressed: () => Navigator.pop(context),
//             child: const Text('OK'),
//           ),
//         ],
//       ),
//     );
//   }

//   // ---- Edit / Delete actions ----
//   void _showMessageActions(MessageItem msg) {
//     if (msg.isDeleted) return;
//     final isOwn = msg.sender.uid == curUserId;

//     showCupertinoModalPopup(
//       context: context,
//       builder: (_) => CupertinoActionSheet(
//         actions: [
//           // Reply — available for all messages
//           CupertinoActionSheetAction(
//             onPressed: () {
//               Navigator.pop(context);
//               _setReplyTo(msg);
//             },
//             child: const Text('Reply'),
//           ),
//           if (isOwn)
//             CupertinoActionSheetAction(
//               onPressed: () {
//                 Navigator.pop(context);
//                 _startEditing(msg);
//               },
//               child: const Text('Edit'),
//             ),
//           // Delete — only own messages
//           if (isOwn)
//             CupertinoActionSheetAction(
//               isDestructiveAction: true,
//               onPressed: () {
//                 Navigator.pop(context);
//                 _confirmDelete(msg);
//               },
//               child: const Text('Delete'),
//             ),
//         ],
//         cancelButton: CupertinoActionSheetAction(
//           onPressed: () => Navigator.pop(context),
//           child: const Text('Cancel'),
//         ),
//       ),
//     );
//   }

//   void _confirmDelete(MessageItem msg) {
//     showCupertinoDialog(
//       context: context,
//       builder: (ctx) => CupertinoAlertDialog(
//         title: const Text('Delete message?'),
//         content: const Text('This cannot be undone.'),
//         actions: [
//           CupertinoDialogAction(
//             onPressed: () => Navigator.pop(ctx),
//             child: const Text('Cancel'),
//           ),
//           CupertinoDialogAction(
//             isDestructiveAction: true,
//             onPressed: () async {
//               Navigator.pop(ctx);
//               try {
//                 await deleteMessage(widget.chatId, msg.id);
//                 if (!mounted) return;
//                 _store.removeById(msg.id);
//                 _rebuildDisplay();
//               } catch (e) {
//                 if (mounted) {
//                   showCupertinoDialog(
//                     context: context,
//                     builder: (_) => CupertinoAlertDialog(
//                       title: const Text('Error'),
//                       content: Text('Failed to delete: $e'),
//                       actions: [
//                         CupertinoDialogAction(
//                           isDefaultAction: true,
//                           onPressed: () => Navigator.pop(context),
//                           child: const Text('OK'),
//                         ),
//                       ],
//                     ),
//                   );
//                 }
//               }
//             },
//             child: const Text('Delete'),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   Widget build(BuildContext context) {
//     final chatName = widget.chatName.isEmpty
//         ? 'Chat ${widget.chatId}'
//         : widget.chatName;
//     return PopScope(
//       onPopInvokedWithResult: (didPop, _) {
//         if (didPop) _saveDraft();
//       },
//       child: CupertinoPageScaffold(
//         backgroundColor: const Color(0xFFECE5DD),
//         child: GestureDetector(
//           onTap: () => FocusScope.of(context).unfocus(),
//           child: Stack(
//             children: [
//               // Main content column (messages + input)
//               SafeArea(
//                 child: Column(
//                   children: [
//                     Expanded(
//                       child: Stack(
//                         children: [
//                           // messages
//                           _buildBody(),
//                           // scroll to bottom button
//                           if (_showScrollToBottom)
//                             Positioned(
//                               right: 16,
//                               bottom: 16,
//                               child: CupertinoButton(
//                                 padding: EdgeInsets.zero,
//                                 onPressed: _scrollToBottom,
//                                 child: Container(
//                                   width: 40,
//                                   height: 40,
//                                   decoration: BoxDecoration(
//                                     color: CupertinoColors.systemGrey5
//                                         .resolveFrom(context),
//                                     shape: BoxShape.circle,
//                                     boxShadow: [
//                                       BoxShadow(
//                                         color: CupertinoColors.systemGrey
//                                             .withAlpha(80),
//                                         blurRadius: 6,
//                                         offset: const Offset(0, 2),
//                                       ),
//                                     ],
//                                   ),
//                                   child: Icon(
//                                     CupertinoIcons.chevron_down,
//                                     size: 20,
//                                     color: CupertinoColors.label.resolveFrom(
//                                       context,
//                                     ),
//                                   ),
//                                 ),
//                               ),
//                             ),
//                         ],
//                       ),
//                     ),
//                     Padding(
//                       padding: const EdgeInsets.only(top: 5),
//                       child: _buildInput(),
//                     ),
//                   ],
//                 ),
//               ),
//               // Gradient title bar overlay
//               Positioned(
//                 top: 0,
//                 left: 0,
//                 right: 0,
//                 child: Container(
//                   decoration: const BoxDecoration(
//                     gradient: LinearGradient(
//                       begin: Alignment(0, 0.5),
//                       end: Alignment.bottomCenter,
//                       colors: [
//                         Color(0xFFECE5DD), // solid
//                         Color(0xDFECE5DD),
//                         Color(0xCCECE5DD),
//                         Color(0x80ECE5DD),
//                         Color(0x40ECE5DD),
//                         Color(0x00ECE5DD), // transparent
//                       ],
//                       // stops: [0.0, 1.0],
//                       stops: [0.0, 0.5, 0.6, 0.8, 0.9, 1.0],
//                     ),
//                   ),
//                   child: SafeArea(
//                     bottom: false,
//                     child: SizedBox(
//                       height: _titleBarHeight,
//                       child: Padding(
//                         padding: const EdgeInsets.only(bottom: 36),
//                         child: Stack(
//                           alignment: Alignment.center,
//                           children: [
//                             // Centered title (independent of buttons)
//                             Text(
//                               chatName,
//                               textAlign: TextAlign.center,
//                               style: const TextStyle(
//                                 fontSize: 17,
//                                 fontWeight: FontWeight.w600,
//                               ),
//                               overflow: TextOverflow.ellipsis,
//                             ),
//                             // Back button on left
//                             Positioned(
//                               left: 8,
//                               child: CupertinoButton(
//                                 padding: EdgeInsets.zero,
//                                 onPressed: () {
//                                   _saveDraft();
//                                   Navigator.pop(context);
//                                 },
//                                 child: const Icon(
//                                   CupertinoIcons.back,
//                                   size: 28,
//                                 ),
//                               ),
//                             ),
//                             // Action buttons on right
//                             Positioned(
//                               right: 8,
//                               child: Row(
//                                 mainAxisSize: MainAxisSize.min,
//                                 children: [
//                                   CupertinoButton(
//                                     padding: EdgeInsets.zero,
//                                     onPressed: () => Navigator.push(
//                                       context,
//                                       CupertinoPageRoute(
//                                         builder: (_) => GroupMembersPage(
//                                           chatId: widget.chatId,
//                                         ),
//                                       ),
//                                     ),
//                                     child: const Icon(
//                                       CupertinoIcons.person_2_fill,
//                                       size: 22,
//                                     ),
//                                   ),
//                                   CupertinoButton(
//                                     padding: EdgeInsets.zero,
//                                     onPressed: () => Navigator.push(
//                                       context,
//                                       CupertinoPageRoute(
//                                         builder: (_) => GroupSettingsPage(
//                                           chatId: widget.chatId,
//                                           currentName: widget.chatName,
//                                         ),
//                                       ),
//                                     ),
//                                     child: const Icon(
//                                       CupertinoIcons.gear_solid,
//                                       size: 22,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildBody() {
//     if (_isLoading) {
//       return const Center(child: CupertinoActivityIndicator());
//     }
//     if (_errorMessage != null) {
//       return Center(
//         child: Padding(
//           padding: const EdgeInsets.all(24),
//           child: Column(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Text(_errorMessage!, textAlign: TextAlign.center),
//               const SizedBox(height: 16),
//               CupertinoButton.filled(
//                 onPressed: _loadMessages,
//                 child: const Text('Retry'),
//               ),
//             ],
//           ),
//         ),
//       );
//     }
//     if (_displayItems.isEmpty) {
//       return const Center(
//         child: Text('No messages yet', style: TextStyle(fontSize: 20)),
//       );
//     }
//     final showTopLoader = _nextCursor != null && _isLoadingMore;
//     final itemCount = _displayItems.length + (showTopLoader ? 1 : 0);
//     return ListView.builder(
//       controller: _scrollController,
//       reverse: true,
//       padding: const EdgeInsets.only(top: _titleBarHeight),
//       itemCount: itemCount,
//       itemBuilder: (context, index) {
//         if (showTopLoader && index == itemCount - 1) {
//           return const Padding(
//             padding: EdgeInsets.symmetric(vertical: 16),
//             child: Center(child: CupertinoActivityIndicator()),
//           );
//         }

//         final msg = _displayItems[index];
//         final isHighlighted = _highlightedMessageId == msg.id;

//         // Sender name grouping: show on first (oldest) of contiguous block.
//         bool showSenderName = true;
//         if (index < _displayItems.length - 1) {
//           final next = _displayItems[index + 1];
//           if (next.sender.uid == msg.sender.uid) {
//             showSenderName = false;
//           }
//         }

//         // Avatar grouping: show on last (newest) of contiguous block.
//         bool showAvatar = true;
//         if (index > 0) {
//           final prev = _displayItems[index - 1];
//           if (prev.sender.uid == msg.sender.uid) {
//             showAvatar = false;
//           }
//         }

//         return _MessageRow(
//           key: ValueKey(msg.id),
//           message: msg,
//           isHighlighted: isHighlighted,
//           onLongPress: () => _showMessageActions(msg),
//           onReply: () => _setReplyTo(msg),
//           onTapReply: msg.replyToMessage != null
//               ? () => _jumpToMessage(msg.replyToMessage!.id)
//               : null,
//           showSenderName: showSenderName,
//           showAvatar: showAvatar,
//         );
//       },
//     );
//   }

//   Widget _buildInput() {
//     // when editing or replying to a message, show the preview of that message
//     final hasPreview = _inputState is! InputEmpty;

//     return Column(
//       children: [
//         Divider(height: 0.5, color: CupertinoColors.separator),
//         Padding(
//           padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
//           child: Column(
//             children: [
//               Row(
//                 crossAxisAlignment: CrossAxisAlignment.end,
//                 children: [
//                   // attachment button
//                   CupertinoButton(
//                     padding: EdgeInsets.zero,
//                     // padding: const EdgeInsets.fromLTRB(1, 1, 1, 0),
//                     onPressed: () {
//                       // TODO: implement attachment sheet
//                     },
//                     child: Icon(
//                       CupertinoIcons.add_circled,
//                       color: CupertinoColors.activeBlue.resolveFrom(context),
//                       size: 28,
//                     ),
//                   ),
//                   const SizedBox(width: 4),
//                   // Unified input box (Preview + Text field)
//                   Expanded(
//                     child: Container(
//                       decoration: BoxDecoration(
//                         color: CupertinoColors.systemBackground.resolveFrom(
//                           context,
//                         ),
//                         borderRadius: BorderRadius.circular(20),
//                         border: Border.all(
//                           color: CupertinoColors.systemGrey4.resolveFrom(
//                             context,
//                           ),
//                           width: 1.0,
//                         ),
//                       ),
//                       clipBehavior: Clip.antiAlias,
//                       child: Column(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           // preview bar: switch input state to get msg /and sender
//                           switch (_inputState) {
//                             InputReplying(:final message) => _replyToMsg(
//                               title:
//                                   'Replying to ${message.sender.name ?? 'User ${message.sender.uid}'}',
//                               body: message.message ?? '',
//                             ),
//                             InputEditing(:final message) => _buildPreviewBar(
//                               title: 'Edit Message',
//                               body: message.message ?? '',
//                             ),
//                             InputEmpty() => const SizedBox.shrink(),
//                           },
//                           if (hasPreview)
//                             // use container as divider
//                             Container(
//                               height: 0.5,
//                               color: CupertinoColors.separator.resolveFrom(
//                                 context,
//                               ),
//                             ),
//                           // text field
//                           CupertinoScrollbar(
//                             controller: _inputScrollController,
//                             child: CupertinoTextField(
//                               controller: _textController,
//                               scrollController: _inputScrollController,
//                               placeholder: 'Message',
//                               maxLines: 5,
//                               minLines: 1,
//                               padding: const EdgeInsets.symmetric(
//                                 horizontal: 16,
//                                 vertical: 8,
//                               ),
//                               decoration: null, // use container decoration
//                             ),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ),
//                   const SizedBox(width: 8),
//                   // Send button
//                   GestureDetector(
//                     onTap: _sendMessage,
//                     child: Container(
//                       width: 36,
//                       height: 36,
//                       decoration: const BoxDecoration(
//                         color: CupertinoColors.activeBlue,
//                         shape: BoxShape.circle,
//                       ),
//                       child: const Icon(
//                         CupertinoIcons.paperplane_fill,
//                         size: 20,
//                         color: CupertinoColors.white,
//                       ),
//                     ),
//                   ),
//                   const SizedBox(width: 8),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }

//   Widget _replyToMsg({required String title, required String body}) {
//     _textController.clear();
//     return _buildPreviewBar(title: title, body: body);
//   }

//   // show preview bar when replying or editing
//   Widget _buildPreviewBar({required String title, required String body}) {
//     return Container(
//       padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
//       decoration: BoxDecoration(
//         color: CupertinoColors.systemGrey5.resolveFrom(context),
//         border: const Border(
//           left: BorderSide(color: CupertinoColors.activeBlue, width: 3),
//         ),
//         borderRadius: const BorderRadius.only(
//           topLeft: Radius.circular(20),
//           topRight: Radius.circular(20),
//         ),
//       ),
//       child: Row(
//         children: [
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Text(
//                   title,
//                   style: const TextStyle(
//                     fontWeight: FontWeight.w600,
//                     fontSize: 13,
//                     color: CupertinoColors.activeBlue,
//                   ),
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//                 const SizedBox(height: 2),
//                 Text(
//                   body,
//                   maxLines: 1,
//                   overflow: TextOverflow.ellipsis,
//                   style: TextStyle(
//                     fontSize: 13,
//                     color: CupertinoColors.secondaryLabel.resolveFrom(context),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//           // cancel button
//           CupertinoButton(
//             padding: EdgeInsets.zero,
//             minimumSize: const Size(30, 30),
//             onPressed: _clearInputMessage,
//             child: Icon(
//               CupertinoIcons.xmark_circle_fill,
//               size: 20,
//               color: CupertinoColors.systemGrey3.resolveFrom(context),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// // ---------------------------------------------------------------------------
// // _MessageRow — message bubble with avatar, inline time, reply quote,
// // swipe-to-reply gesture
// // ---------------------------------------------------------------------------

// class _MessageRow extends StatefulWidget {
//   const _MessageRow({
//     super.key,
//     required this.message,
//     this.isHighlighted = false,
//     this.onLongPress,
//     this.onReply,
//     this.onTapReply,
//     this.showSenderName = true,
//     this.showAvatar = true,
//   });

//   final MessageItem message;
//   final bool isHighlighted;
//   final VoidCallback? onLongPress;
//   final VoidCallback? onReply;
//   final VoidCallback? onTapReply;
//   final bool showSenderName;
//   final bool showAvatar;

//   @override
//   State<_MessageRow> createState() => _MessageRowState();
// }

// class _MessageRowState extends State<_MessageRow>
//     with SingleTickerProviderStateMixin {
//   double _dragOffset = 0;
//   bool _hasTriggeredReply = false;
//   static const double _replyThreshold = 60;

//   bool get _isMe => widget.message.sender.uid == curUserId;

//   void _onHorizontalDragUpdate(DragUpdateDetails details) {
//     setState(() {
//       // Only allow dragging to the left (negative offset)
//       _dragOffset = (_dragOffset + details.delta.dx).clamp(
//         -_replyThreshold * 1.3,
//         0,
//       );
//     });
//     if (!_hasTriggeredReply && _dragOffset <= -_replyThreshold) {
//       _hasTriggeredReply = true;
//     }
//   }

//   void _onHorizontalDragEnd(DragEndDetails details) {
//     if (_hasTriggeredReply) {
//       widget.onReply?.call();
//     }
//     _hasTriggeredReply = false;
//     setState(() => _dragOffset = 0);
//   }

//   @override
//   Widget build(BuildContext context) {
//     final message = widget.message;
//     final screenWidth = MediaQuery.of(context).size.width;
//     final msgText = message.message ?? '';
//     final senderName = message.sender.name ?? 'User ${message.sender.uid}';
//     final timeStr = _formatTime(message.createdAt);

//     final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;

//     final bubbleColor = _isMe
//         ? CupertinoColors.activeBlue
//         : (isDark ? CupertinoColors.systemGrey5.darkColor : Color(0xfff0f0f0));
//     final textColor = _isMe
//         ? CupertinoColors.white
//         : CupertinoColors.label.resolveFrom(context);
//     // edited label, time
//     final metaColor = _isMe
//         ? CupertinoColors.white.withAlpha(180)
//         : CupertinoColors.secondaryLabel.resolveFrom(context);

//     // Avatar initial
//     final initial = (senderName.isNotEmpty ? senderName[0] : '?').toUpperCase();

//     final maxBubbleWidth = screenWidth * 0.75;

//     // edited label, time
//     final editedLabel = message.isEdited ? 'edited ' : '';
//     Widget timeWidget = Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         if (message.isEdited)
//           Padding(
//             padding: const EdgeInsets.only(right: 3),
//             child: Text(
//               'edited',
//               style: TextStyle(color: metaColor, fontSize: 11),
//             ),
//           ),
//         Text(timeStr, style: TextStyle(color: metaColor, fontSize: 11)),
//       ],
//     );

//     // Measure time width to create a matching invisible spacer.
//     final timePainter = TextPainter(
//       text: TextSpan(
//         text: ' $editedLabel$timeStr',
//         style: const TextStyle(fontSize: 11),
//       ),
//       maxLines: 1,
//       textDirection: TextDirection.ltr,
//     )..layout(maxWidth: double.infinity);
//     final timeSpacerWidth = timePainter.width + 8;

//     // msg content, edited label, date/time
//     // Link detection colors
//     final linkColor = _isMe
//         ? CupertinoColors.white
//         : CupertinoColors.activeBlue;

//     Widget bubbleContent = Stack(
//       children: [
//         Text.rich(
//           TextSpan(
//             children: [
//               ..._buildLinkedSpans(
//                 msgText,
//                 TextStyle(color: textColor, fontSize: 15),
//                 linkColor,
//               ),
//               WidgetSpan(child: SizedBox(width: timeSpacerWidth, height: 14)),
//             ],
//           ),
//         ),
//         Positioned(right: 0, bottom: 0, child: timeWidget),
//       ],
//     );

//     // the whole bubble
//     Widget fullContent = Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         // sender name
//         if (!_isMe && widget.showSenderName)
//           Padding(
//             padding: const EdgeInsets.only(bottom: 2),
//             child: Text(
//               senderName,
//               style: TextStyle(
//                 fontWeight: FontWeight.w700,
//                 fontSize: 13,
//                 color: textColor,
//               ),
//             ),
//           ),
//         // reply quote
//         if (message.replyToMessage != null)
//           GestureDetector(
//             onTap: widget.onTapReply,
//             child: _buildReplyQuote(context, message.replyToMessage!),
//           ),
//         // message content
//         bubbleContent,
//       ],
//     );

//     Widget bubble = Container(
//       constraints: BoxConstraints(maxWidth: maxBubbleWidth),
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//       decoration: BoxDecoration(
//         color: bubbleColor,
//         borderRadius: BorderRadius.only(
//           topLeft: const Radius.circular(18),
//           topRight: const Radius.circular(18),
//           bottomLeft: Radius.circular(_isMe ? 18 : 4),
//           bottomRight: Radius.circular(_isMe ? 4 : 18),
//         ),
//       ),
//       child: fullContent,
//     );

//     Widget avatar = Container(
//       width: 30,
//       height: 30,
//       decoration: BoxDecoration(
//         color: isDark
//             ? CupertinoColors.systemGrey4.darkColor
//             : CupertinoColors.systemGrey4.color,
//         shape: BoxShape.circle,
//       ),
//       alignment: Alignment.center,
//       child: Text(
//         initial,
//         style: const TextStyle(
//           fontSize: 13,
//           fontWeight: FontWeight.w600,
//           color: CupertinoColors.white,
//         ),
//       ),
//     );

//     // Reply icon that appears on the right when swiping
//     final replyIconOpacity = (_dragOffset.abs() / _replyThreshold).clamp(
//       0.0,
//       1.0,
//     );

//     Widget messageRow = AnimatedContainer(
//       duration: const Duration(milliseconds: 600),
//       decoration: BoxDecoration(
//         color: widget.isHighlighted
//             ? CupertinoColors.systemYellow.withAlpha(60)
//             : const Color(0x00000000),
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
//         child: Row(
//           mainAxisAlignment: _isMe
//               ? MainAxisAlignment.end
//               : MainAxisAlignment.start,
//           crossAxisAlignment: CrossAxisAlignment.end,
//           children: _isMe
//               ? [
//                   bubble,
//                   if (widget.showAvatar) ...[
//                     const SizedBox(width: 6),
//                     avatar,
//                   ] else
//                     const SizedBox(width: 36),
//                 ]
//               : [
//                   if (widget.showAvatar) ...[
//                     avatar,
//                     const SizedBox(width: 6),
//                   ] else
//                     const SizedBox(width: 36),
//                   bubble,
//                 ],
//         ),
//       ),
//     );

//     return GestureDetector(
//       onLongPress: widget.onLongPress,
//       onHorizontalDragUpdate: _onHorizontalDragUpdate,
//       onHorizontalDragEnd: _onHorizontalDragEnd,
//       child: Stack(
//         alignment: Alignment.centerRight,
//         children: [
//           // Reply icon behind the message
//           Positioned(
//             right: 12,
//             child: Opacity(
//               opacity: replyIconOpacity,
//               child: Container(
//                 width: 28,
//                 height: 28,
//                 decoration: BoxDecoration(
//                   color: CupertinoColors.systemGrey5.resolveFrom(context),
//                   shape: BoxShape.circle,
//                 ),
//                 child: Icon(
//                   CupertinoIcons.reply,
//                   size: 22,
//                   color: CupertinoColors.activeBlue,
//                 ),
//               ),
//             ),
//           ),
//           // The actual message, translated by drag offset
//           AnimatedContainer(
//             duration: _dragOffset == 0
//                 ? const Duration(milliseconds: 200)
//                 : Duration.zero,
//             curve: Curves.easeOut,
//             transform: Matrix4.translationValues(_dragOffset, 0, 0),
//             child: messageRow,
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _buildReplyQuote(BuildContext context, ReplyToMessage reply) {
//     final replySender = reply.sender.name ?? 'User ${reply.sender.uid}';
//     final replyText = reply.isDeleted
//         ? 'Message deleted'
//         : (reply.message ?? '');

//     final isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark;

//     final quoteBackgroundColor = _isMe
//         ? Color.lerp(CupertinoColors.activeBlue, const Color(0xFF000000), 0.15)!
//         : (isDark
//               ? CupertinoColors.systemGrey4.darkColor
//               : CupertinoColors.systemGrey5.color);
//     final quoteBorderColor = _isMe
//         ? CupertinoColors.white.withAlpha(150)
//         : CupertinoColors.activeBlue;

//     return Container(
//       margin: const EdgeInsets.only(bottom: 6),
//       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//       decoration: BoxDecoration(
//         color: quoteBackgroundColor,
//         border: Border(left: BorderSide(color: quoteBorderColor, width: 3)),
//         borderRadius: const BorderRadius.only(
//           topRight: Radius.circular(4),
//           bottomRight: Radius.circular(4),
//         ),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Text(
//             replySender,
//             style: TextStyle(
//               fontWeight: FontWeight.w600,
//               fontSize: 12,
//               color: quoteBorderColor,
//             ),
//           ),
//           Text(
//             replyText,
//             maxLines: 2,
//             overflow: TextOverflow.ellipsis,
//             style: TextStyle(
//               fontSize: 13,
//               color: _isMe
//                   ? CupertinoColors.white.withAlpha(200)
//                   : CupertinoColors.secondaryLabel.resolveFrom(context),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // ---- Link-detection helper ----
//   static final RegExp _urlRegex = RegExp(
//     r'(https?://[^\s<>]+|www\.[^\s<>]+)',
//     caseSensitive: false,
//   );

//   List<InlineSpan> _buildLinkedSpans(
//     String text,
//     TextStyle baseStyle,
//     Color linkColor,
//   ) {
//     final spans = <InlineSpan>[];
//     int lastEnd = 0;
//     for (final match in _urlRegex.allMatches(text)) {
//       if (match.start > lastEnd) {
//         spans.add(
//           TextSpan(
//             text: text.substring(lastEnd, match.start),
//             style: baseStyle,
//           ),
//         );
//       }
//       final url = match.group(0)!;
//       final recognizer = TapGestureRecognizer()
//         ..onTap = () {
//           final uri = url.startsWith('http') ? url : 'https://$url';
//           launchUrl(Uri.parse(uri), mode: LaunchMode.externalApplication);
//         };
//       spans.add(
//         TextSpan(
//           text: url,
//           style: baseStyle.copyWith(
//             color: linkColor,
//             decoration: TextDecoration.underline,
//             decorationColor: linkColor,
//           ),
//           recognizer: recognizer,
//         ),
//       );
//       lastEnd = match.end;
//     }
//     if (lastEnd < text.length) {
//       spans.add(TextSpan(text: text.substring(lastEnd), style: baseStyle));
//     }
//     // If no links found, return a single span
//     if (spans.isEmpty) {
//       spans.add(TextSpan(text: text, style: baseStyle));
//     }
//     return spans;
//   }

//   String _formatTime(String iso) {
//     if (iso.isEmpty) return '';
//     try {
//       final dt = DateTime.parse(iso);
//       return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
//     } catch (_) {
//       return iso;
//     }
//   }
// }
