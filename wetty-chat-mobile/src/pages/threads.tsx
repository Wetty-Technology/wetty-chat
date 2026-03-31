import { useCallback, useEffect, useState } from 'react';
import {
  IonContent,
  IonHeader,
  IonPage,
  IonRefresher,
  IonRefresherContent,
  IonSpinner,
  IonToolbar,
  type RefresherEventDetail,
} from '@ionic/react';
import { Trans } from '@lingui/react/macro';
import { useDispatch, useSelector } from 'react-redux';
import { useHistory } from 'react-router-dom';
import { getThreads } from '@/api/threads';
import {
  selectThreads,
  selectThreadsLoaded,
  selectThreadsNextCursor,
  setThreadsList,
  appendThreads,
} from '@/store/threadsSlice';
import { selectEffectiveLocale } from '@/store/settingsSlice';
import { TitleWithConnectionStatus } from '@/components/TitleWithConnectionStatus';
import { ThreadListRow } from '@/components/chat/ThreadListRow';
import styles from './threads.module.scss';

interface ThreadsListCoreProps {
  onThreadSelect: (chatId: string, threadRootId: string) => void;
}

export function ThreadsListCore({ onThreadSelect }: ThreadsListCoreProps) {
  const dispatch = useDispatch();
  const threads = useSelector(selectThreads);
  const isLoaded = useSelector(selectThreadsLoaded);
  const nextCursor = useSelector(selectThreadsNextCursor);
  const locale = useSelector(selectEffectiveLocale);
  const [, setIsRefreshing] = useState(false);
  const [isLoadingMore, setIsLoadingMore] = useState(false);

  const fetchThreads = useCallback(async () => {
    try {
      const res = await getThreads({ limit: 20 });
      dispatch(setThreadsList({ threads: res.data.threads, nextCursor: res.data.nextCursor }));
    } catch (err) {
      console.error('Failed to fetch threads', err);
    }
  }, [dispatch]);

  useEffect(() => {
    if (!isLoaded) {
      void fetchThreads();
    }
  }, [isLoaded, fetchThreads]);

  const handleRefresh = useCallback(
    async (event: CustomEvent<RefresherEventDetail>) => {
      setIsRefreshing(true);
      try {
        await fetchThreads();
      } finally {
        setIsRefreshing(false);
        event.detail.complete();
      }
    },
    [fetchThreads],
  );

  const handleLoadMore = useCallback(async () => {
    if (!nextCursor || isLoadingMore) return;
    setIsLoadingMore(true);
    try {
      const res = await getThreads({ limit: 20, before: nextCursor });
      dispatch(appendThreads({ threads: res.data.threads, nextCursor: res.data.nextCursor }));
    } catch (err) {
      console.error('Failed to load more threads', err);
    } finally {
      setIsLoadingMore(false);
    }
  }, [nextCursor, isLoadingMore, dispatch]);

  const handleScroll = useCallback(
    (e: CustomEvent) => {
      const target = e.detail as { scrollTop: number; scrollHeight: number; clientHeight: number };
      if (target.scrollHeight - target.scrollTop - target.clientHeight < 200) {
        void handleLoadMore();
      }
    },
    [handleLoadMore],
  );

  if (!isLoaded) {
    return (
      <IonContent>
        <div className={styles.emptyState}>
          <IonSpinner />
        </div>
      </IonContent>
    );
  }

  if (threads.length === 0) {
    return (
      <IonContent>
        <IonRefresher slot="fixed" onIonRefresh={handleRefresh}>
          <IonRefresherContent />
        </IonRefresher>
        <div className={styles.emptyState}>
          <p className={styles.emptyText}>
            <Trans>No threads yet</Trans>
          </p>
          <p className={styles.emptySubtext}>
            <Trans>Threads you create or reply to will appear here</Trans>
          </p>
        </div>
      </IonContent>
    );
  }

  return (
    <IonContent scrollEvents onIonScroll={handleScroll}>
      <IonRefresher slot="fixed" onIonRefresh={handleRefresh}>
        <IonRefresherContent />
      </IonRefresher>
      <div>
        {threads.map((thread) => (
          <ThreadListRow key={thread.threadRootMessage.id} thread={thread} locale={locale} onSelect={onThreadSelect} />
        ))}
      </div>
      {isLoadingMore && (
        <div className={styles.loadingMore}>
          <IonSpinner name="dots" />
        </div>
      )}
    </IonContent>
  );
}

export default function ThreadsPage() {
  const history = useHistory();

  const handleThreadSelect = useCallback(
    (chatId: string, threadRootId: string) => {
      history.push(`/chats/chat/${chatId}/thread/${threadRootId}`);
    },
    [history],
  );

  return (
    <IonPage>
      <IonHeader>
        <IonToolbar>
          <TitleWithConnectionStatus>
            <Trans>Threads</Trans>
          </TitleWithConnectionStatus>
        </IonToolbar>
      </IonHeader>
      <ThreadsListCore onThreadSelect={handleThreadSelect} />
    </IonPage>
  );
}
