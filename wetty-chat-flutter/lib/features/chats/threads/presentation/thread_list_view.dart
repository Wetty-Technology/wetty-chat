import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/routing/route_names.dart';
import '../../../../app/theme/style_config.dart';
import '../application/thread_list_view_model.dart';
import '../models/thread_models.dart';
import '../../list/presentation/widgets/swipe_to_action_row.dart';
import 'thread_list_row.dart';

/// Displays a paginated list of threads the current user is subscribed to.
///
/// When [embedded] is true the scaffold and navigation bar are omitted so the
/// widget can be placed inside a parent tab view.
class ThreadListView extends ConsumerStatefulWidget {
  const ThreadListView({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<ThreadListView> createState() => _ThreadListViewState();
}

class _ThreadListViewState extends ConsumerState<ThreadListView> {
  late final ScrollController _scrollController;

  bool get _supportsPullToRefresh {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final viewState = ref.read(threadListViewModelProvider).value;
    if (viewState == null) return;
    if (!viewState.hasMore || viewState.isLoadingMore) return;

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      ref.read(threadListViewModelProvider.notifier).loadMoreThreads();
    }
  }

  Future<void> _refreshThreads() {
    return ref
        .read(threadListViewModelProvider.notifier)
        .refreshThreads(userInitiated: true);
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(threadListViewModelProvider);

    final body = SafeArea(
      child: asyncState.when(
        loading: () => const Center(child: CupertinoActivityIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(error.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                CupertinoButton.filled(
                  onPressed: () => ref.invalidate(threadListViewModelProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (viewState) => _buildBody(viewState),
      ),
    );

    if (widget.embedded) return body;

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('Threads')),
      child: body,
    );
  }

  Widget _buildBody(ThreadListViewState viewState) {
    if (viewState.errorMessage != null && viewState.threads.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(viewState.errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              CupertinoButton.filled(
                onPressed: () => ref.invalidate(threadListViewModelProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (viewState.threads.isEmpty) {
      return Center(
        child: Text('No threads yet', style: appSecondaryTextStyle(context)),
      );
    }

    if (_supportsPullToRefresh) {
      return CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          CupertinoSliverRefreshControl(onRefresh: _refreshThreads),
          SliverList.builder(
            itemCount: viewState.threads.length,
            itemBuilder: (context, index) =>
                _buildThreadRow(viewState.threads[index]),
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
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: viewState.threads.length + (viewState.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= viewState.threads.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CupertinoActivityIndicator()),
          );
        }
        return _buildThreadRow(viewState.threads[index]);
      },
    );
  }

  Widget _buildThreadRow(ThreadListItem thread) {
    return SwipeToActionRow(
      key: ValueKey('thread-${thread.chatId}-${thread.threadRootId}'),
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
