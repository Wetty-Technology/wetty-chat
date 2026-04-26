import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routing/route_names.dart';
import '../../../app/theme/style_config.dart';
import '../model/thread_list_item.dart';
import 'widgets/thread_list_row.dart';
import '../application/thread_list_v2_view_model.dart';

class ThreadListV2View extends ConsumerWidget {
  const ThreadListV2View({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(threadListV2ViewModelProvider);

    return asyncState.when(
      loading: () => const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CupertinoActivityIndicator()),
      ),
      error: (error, _) => SliverFillRemaining(
        hasScrollBody: false,
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
          return SliverFillRemaining(
            hasScrollBody: false,
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
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                'No threads yet',
                style: appSecondaryTextStyle(context),
              ),
            ),
          );
        }

        return SliverMainAxisGroup(
          slivers: [
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
