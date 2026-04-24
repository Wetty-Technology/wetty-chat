import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/route_names.dart';
import '../../../app/theme/style_config.dart';
import '../../chats/threads/models/thread_models.dart';
import '../../chats/threads/presentation/thread_list_row.dart';
import '../application/thread_list_v2_view_model.dart';

class ThreadListV2View extends ConsumerWidget {
  const ThreadListV2View({
    super.key,
    this.scrollController,
    this.supportsPullToRefresh = false,
  });

  final ScrollController? scrollController;
  final bool supportsPullToRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(threadListV2ViewModelProvider);

    return asyncState.when(
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
                onPressed: () => ref.invalidate(threadListV2ViewModelProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (viewState) {
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
                    onPressed: () =>
                        ref.invalidate(threadListV2ViewModelProvider),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        if (viewState.threads.isEmpty) {
          return Center(
            child: Text(
              'No threads yet',
              style: appSecondaryTextStyle(context),
            ),
          );
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
                    .read(threadListV2ViewModelProvider.notifier)
                    .refreshThreads(),
              ),
              SliverList.builder(
                itemCount: viewState.threads.length,
                itemBuilder: (context, index) =>
                    _ThreadListV2Row(thread: viewState.threads[index]),
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
              viewState.threads.length + (viewState.isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= viewState.threads.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CupertinoActivityIndicator()),
              );
            }
            return _ThreadListV2Row(thread: viewState.threads[index]);
          },
        );
      },
    );
  }
}

class _ThreadListV2Row extends StatelessWidget {
  const _ThreadListV2Row({required this.thread});

  final ThreadListItem thread;

  @override
  Widget build(BuildContext context) {
    return ThreadListRow(
      thread: thread,
      onTap: () {
        context.push(
          AppRoutes.threadDetail(thread.chatId, thread.threadRootId.toString()),
        );
      },
    );
  }
}
