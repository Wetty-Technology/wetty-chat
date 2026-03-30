import { useCallback, useEffect, useRef, useState } from 'react';
import { IonChip, IonItem, IonLabel, IonSearchbar, IonSpinner, useIonToast } from '@ionic/react';
import { t } from '@lingui/core/macro';
import { Trans } from '@lingui/react/macro';
import { listGroups, type GroupSearchMode, type GroupSelectorItem, type GroupSelectorScope } from '@/api/group';
import { UserAvatar } from '@/components/UserAvatar';
import { getChatDisplayName, getGroupVisibilityLabel } from '@/utils/chatDisplay';
import { Virtuoso } from 'react-virtuoso';
import styles from './GroupSelector.module.scss';

const GROUPS_PAGE_SIZE = 50;
const SEARCH_DEBOUNCE_MS = 250;

interface GroupSelectorProps {
  scope?: GroupSelectorScope;
  placeholder?: string;
  onSelect: (group: GroupSelectorItem) => void;
}

interface GroupSearchState {
  q: string;
  mode: GroupSearchMode;
}

function normalizeSearchInput(value: string): string {
  return value.trim();
}

function getSearchKey(search: GroupSearchState | null, scope: GroupSelectorScope): string {
  if (!search) {
    return `browse:${scope}`;
  }

  return `${scope}:${search.mode}:${search.q}`;
}

function mergeGroups(existing: GroupSelectorItem[], incoming: GroupSelectorItem[]): GroupSelectorItem[] {
  const seen = new Set(existing.map((group) => group.id));
  const next = [...existing];

  for (const group of incoming) {
    if (seen.has(group.id)) continue;
    seen.add(group.id);
    next.push(group);
  }

  return next;
}

export function GroupSelector({ scope = 'joined', placeholder = t`Search groups`, onSelect }: GroupSelectorProps) {
  const [presentToast] = useIonToast();
  const [groups, setGroups] = useState<GroupSelectorItem[]>([]);
  const [initialLoading, setInitialLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [nextCursor, setNextCursor] = useState<string | null>(null);
  const [hasMore, setHasMore] = useState(false);
  const [searchText, setSearchText] = useState('');
  const [activeSearch, setActiveSearch] = useState<GroupSearchState | null>(null);
  const loadingMoreRef = useRef(false);
  const latestInitialLoadRef = useRef(0);
  const activeSearchKeyRef = useRef(getSearchKey(null, scope));

  const showToast = useCallback(
    (message: string, duration = 3000) => {
      presentToast({ message, duration });
    },
    [presentToast],
  );

  useEffect(() => {
    activeSearchKeyRef.current = getSearchKey(activeSearch, scope);
  }, [activeSearch, scope]);

  const updateActiveSearch = useCallback(
    (nextSearch: GroupSearchState | null) => {
      const nextKey = getSearchKey(nextSearch, scope);
      if (nextKey === activeSearchKeyRef.current) {
        return;
      }

      setGroups([]);
      setNextCursor(null);
      setHasMore(false);
      setActiveSearch(nextSearch);
    },
    [scope],
  );

  useEffect(() => {
    const trimmed = normalizeSearchInput(searchText);
    const timeoutId = window.setTimeout(() => {
      updateActiveSearch(
        trimmed
          ? {
              q: trimmed,
              mode: 'autocomplete',
            }
          : null,
      );
    }, SEARCH_DEBOUNCE_MS);

    return () => window.clearTimeout(timeoutId);
  }, [searchText, updateActiveSearch]);

  const submitSearch = useCallback(() => {
    const trimmed = normalizeSearchInput(searchText);
    updateActiveSearch(
      trimmed
        ? {
            q: trimmed,
            mode: 'submitted',
          }
        : null,
    );
  }, [searchText, updateActiveSearch]);

  const loadInitialGroups = useCallback(() => {
    const requestId = latestInitialLoadRef.current + 1;
    latestInitialLoadRef.current = requestId;
    loadingMoreRef.current = false;
    setInitialLoading(true);
    setLoadingMore(false);

    return listGroups({
      scope,
      limit: GROUPS_PAGE_SIZE,
      q: activeSearch?.q,
      mode: activeSearch?.mode,
    })
      .then((res) => {
        if (latestInitialLoadRef.current !== requestId) {
          return;
        }

        setGroups(res.data.groups);
        setNextCursor(res.data.nextCursor);
        setHasMore(res.data.nextCursor != null);
      })
      .catch((err: Error) => {
        if (latestInitialLoadRef.current !== requestId) {
          return;
        }

        showToast(err.message || t`Failed to load groups`);
        setGroups([]);
        setNextCursor(null);
        setHasMore(false);
      })
      .finally(() => {
        if (latestInitialLoadRef.current === requestId) {
          setInitialLoading(false);
        }
      });
  }, [activeSearch, scope, showToast]);

  const loadMoreGroups = useCallback(() => {
    if (!hasMore || !nextCursor || loadingMoreRef.current) {
      return;
    }

    const searchKey = activeSearchKeyRef.current;
    loadingMoreRef.current = true;
    setLoadingMore(true);

    listGroups({
      scope,
      limit: GROUPS_PAGE_SIZE,
      after: nextCursor,
      q: activeSearch?.q,
      mode: activeSearch?.mode,
    })
      .then((res) => {
        if (activeSearchKeyRef.current !== searchKey) {
          return;
        }

        setGroups((current) => mergeGroups(current, res.data.groups));
        setNextCursor(res.data.nextCursor);
        setHasMore(res.data.nextCursor != null);
      })
      .catch((err: Error) => {
        if (activeSearchKeyRef.current !== searchKey) {
          return;
        }

        showToast(err.message || t`Failed to load groups`);
      })
      .finally(() => {
        if (activeSearchKeyRef.current === searchKey) {
          loadingMoreRef.current = false;
          setLoadingMore(false);
        }
      });
  }, [activeSearch, hasMore, nextCursor, scope, showToast]);

  useEffect(() => {
    loadInitialGroups();
  }, [loadInitialGroups]);

  const renderGroupsFooter = useCallback(() => {
    if (loadingMore) {
      return (
        <div className={styles.footerState}>
          <IonSpinner />
        </div>
      );
    }

    if (groups.length === 0) {
      return (
        <div className={styles.emptyState}>
          {activeSearch ? <Trans>No matching groups found.</Trans> : <Trans>No groups found.</Trans>}
        </div>
      );
    }

    return null;
  }, [activeSearch, groups.length, loadingMore]);

  return (
    <div className={styles.root}>
      <IonSearchbar
        className={styles.searchbar}
        value={searchText}
        onIonInput={(event) => setSearchText(event.detail.value ?? '')}
        onKeyDown={(event) => {
          if (event.key === 'Enter') {
            submitSearch();
          }
        }}
        enterkeyhint="search"
        placeholder={placeholder}
        showClearButton="focus"
      />
      <div className={styles.listContainer}>
        {initialLoading ? (
          <div className={styles.loadingState}>
            <IonSpinner />
          </div>
        ) : (
          <Virtuoso
            className={styles.scrollHost}
            data={groups}
            endReached={hasMore ? () => loadMoreGroups() : undefined}
            components={{ Footer: renderGroupsFooter }}
            itemContent={(_, group) => (
              <IonItem className={styles.row} button detail={false} onClick={() => onSelect(group)}>
                <UserAvatar
                  name={getChatDisplayName(group.id, group.name)}
                  avatarUrl={group.avatar}
                  size={40}
                  className={styles.avatar}
                />
                <IonLabel className={styles.label}>
                  <h3>{getChatDisplayName(group.id, group.name)}</h3>
                </IonLabel>
                <IonChip className={styles.visibilityChip} color="medium">
                  {getGroupVisibilityLabel(group.visibility)}
                </IonChip>
              </IonItem>
            )}
          />
        )}
      </div>
    </div>
  );
}
