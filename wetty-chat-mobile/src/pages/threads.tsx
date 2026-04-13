import { useCallback, useEffect, useRef, useState } from 'react';
import {
  IonButtons,
  IonContent,
  IonHeader,
  IonList,
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
import { BackButton } from '@/components/BackButton';
import { ThreadListRow } from '@/components/chat/lists/ThreadListRow';
import styles from './threads.module.scss';

export interface ThreadsListInnerProps {
  activeThreadId?: string;
  onThreadSelect: (chatId: string, threadRootId: string) => void;
}

/**
 * Inner thread list content that does NOT own IonContent.
 * Can be embedded inside another scrollable container (e.g. ChatList).
 * Uses IntersectionObserver for infinite scroll.
 */
export function ThreadsListInner({ activeThreadId, onThreadSelect }: ThreadsListInnerProps) {
  const dispatch = useDispatch();
  const threads = useSelector(selectThreads);
  const isLoaded = useSelector(selectThreadsLoaded);
  const nextCursor = useSelector(selectThreadsNextCursor);
  const locale = useSelector(selectEffectiveLocale);
  const [isLoadingMore, setIsLoadingMore] = useState(false);
  const sentinelRef = useRef<HTMLDivElement>(null);
  const loadMoreRef = useRef<(() => Promise<void>) | undefined>(undefined);

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

  // Keep a ref so the IntersectionObserver callback always calls the latest handleLoadMore
  loadMoreRef.current = handleLoadMore;

  useEffect(() => {
    const sentinel = sentinelRef.current;
    if (!sentinel) return;

    const observer = new IntersectionObserver(
      (entries) => {
        if (entries[0]?.isIntersecting) {
          void loadMoreRef.current?.();
        }
      },
      { rootMargin: '200px' },
    );
    observer.observe(sentinel);
    return () => observer.disconnect();
  }, []);

  if (!isLoaded) {
    return (
      <div className={styles.emptyState}>
        <IonSpinner />
      </div>
    );
  }

  if (threads.length === 0) {
    return (
      <div className={styles.emptyState}>
        <p className={styles.emptyText}>
          <Trans>No threads yet</Trans>
        </p>
        <p className={styles.emptySubtext}>
          <Trans>Threads you create or reply to will appear here</Trans>
        </p>
      </div>
    );
  }

  return (
    <>
      <IonList>
        {threads.map((thread) => (
          <ThreadListRow
            key={thread.threadRootMessage.id}
            thread={thread}
            locale={locale}
            isActive={activeThreadId === thread.threadRootMessage.id}
            onSelect={onThreadSelect}
          />
        ))}
      </IonList>
      {isLoadingMore && (
        <div className={styles.loadingMore}>
          <IonSpinner name="dots" />
        </div>
      )}
      <div ref={sentinelRef} />
    </>
  );
}

interface ThreadsListCoreProps {
  activeThreadId?: string;
  onThreadSelect: (chatId: string, threadRootId: string) => void;
}

export function ThreadsListCore({ activeThreadId, onThreadSelect }: ThreadsListCoreProps) {
  const dispatch = useDispatch();
  const isLoaded = useSelector(selectThreadsLoaded);

  const fetchThreads = useCallback(async () => {
    try {
      const res = await getThreads({ limit: 20 });
      dispatch(setThreadsList({ threads: res.data.threads, nextCursor: res.data.nextCursor }));
    } catch (err) {
      console.error('Failed to fetch threads', err);
    }
  }, [dispatch]);

  const handleRefresh = useCallback(
    async (event: CustomEvent<RefresherEventDetail>) => {
      try {
        await fetchThreads();
      } finally {
        event.detail.complete();
      }
    },
    [fetchThreads],
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

  return (
    <IonContent>
      <IonRefresher slot="fixed" onIonRefresh={handleRefresh}>
        <IonRefresherContent />
      </IonRefresher>
      <ThreadsListInner activeThreadId={activeThreadId} onThreadSelect={onThreadSelect} />
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
          <IonButtons slot="start">
            <BackButton action={{ type: 'back', defaultHref: '/chats' }} />
          </IonButtons>
          <TitleWithConnectionStatus>
            <Trans>Threads</Trans>
          </TitleWithConnectionStatus>
        </IonToolbar>
      </IonHeader>
      <ThreadsListCore onThreadSelect={handleThreadSelect} />
    </IonPage>
  );
}
