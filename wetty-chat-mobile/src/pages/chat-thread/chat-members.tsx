import { useCallback, useEffect, useRef, useState } from 'react';
import {
  IonButton,
  IonButtons,
  IonContent,
  IonHeader,
  IonPage,
  IonSearchbar,
  IonSpinner,
  IonTitle,
  IonToolbar,
  useIonAlert,
  useIonToast,
} from '@ionic/react';
import { useParams } from 'react-router-dom';
import { t } from '@lingui/core/macro';
import { Plural, Trans } from '@lingui/react/macro';
import {
  addMember,
  getMembers,
  type MemberResponse,
  type MemberSearchMode,
  removeMember,
  updateMemberRole,
} from '@/api/group';
import { Virtuoso } from 'react-virtuoso';
import { useSelector } from 'react-redux';
import type { RootState } from '@/store/index';
import { FeatureGate } from '@/components/FeatureGate';
import { BackButton } from '@/components/BackButton';
import type { BackAction } from '@/types/back-action';
import { ChatMemberRow } from '@/components/chat-members/ChatMemberRow';
import type { Sender } from '@/api/messages';
import { UserProfileModal } from '@/components/chat/profiles/UserProfileModal';
import styles from './chat-members.module.scss';

const MEMBERS_PAGE_SIZE = 50;
const SEARCH_DEBOUNCE_MS = 250;

function mergeMembers(existing: MemberResponse[], incoming: MemberResponse[]): MemberResponse[] {
  const seen = new Set(existing.map((member) => member.uid));
  return [...existing, ...incoming.filter((m) => !seen.has(m.uid))];
}

interface ChatMembersCoreProps {
  chatId?: string;
  backAction?: BackAction;
}

interface MemberSearchState {
  q: string;
  mode: MemberSearchMode;
}

function getSearchKey(search: MemberSearchState | null): string {
  return search ? `${search.mode}:${search.q}` : 'browse';
}

export default function ChatMembersCore({ chatId: propChatId, backAction }: ChatMembersCoreProps) {
  const { id } = useParams<{ id: string }>();
  const chatId = propChatId ?? (id ? String(id) : '');
  const currentUserId = useSelector((state: RootState) => state.user.uid);

  const [presentToast] = useIonToast();
  const [presentAlert] = useIonAlert();
  const [profileSender, setProfileSender] = useState<Sender | null>(null);
  const [profileMember, setProfileMember] = useState<MemberResponse | null>(null);

  const [members, setMembers] = useState<MemberResponse[]>([]);
  const [initialLoading, setInitialLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [isAdmin, setIsAdmin] = useState(false);
  const [nextCursor, setNextCursor] = useState<number | null>(null);
  const [hasMore, setHasMore] = useState(false);
  const [searchText, setSearchText] = useState('');
  const [activeSearch, setActiveSearch] = useState<MemberSearchState | null>(null);
  const loadingMoreRef = useRef(false);
  const latestInitialLoadRef = useRef(0);
  const activeSearchKeyRef = useRef(getSearchKey(null));

  const showToast = useCallback(
    (msg: string, duration = 3000) => {
      presentToast({ message: msg, duration });
    },
    [presentToast],
  );

  useEffect(() => {
    activeSearchKeyRef.current = getSearchKey(activeSearch);
  }, [activeSearch]);

  const updateActiveSearch = useCallback((nextSearch: MemberSearchState | null) => {
    const nextKey = getSearchKey(nextSearch);
    if (nextKey === activeSearchKeyRef.current) {
      return;
    }

    setMembers([]);
    setNextCursor(null);
    setHasMore(false);
    setActiveSearch(nextSearch);
  }, []);

  useEffect(() => {
    const trimmed = searchText.trim();
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
    const trimmed = searchText.trim();
    updateActiveSearch(
      trimmed
        ? {
            q: trimmed,
            mode: 'submitted',
          }
        : null,
    );
  }, [searchText, updateActiveSearch]);

  const loadInitialMembers = useCallback(() => {
    if (!chatId) {
      setMembers([]);
      setInitialLoading(false);
      setLoadingMore(false);
      setNextCursor(null);
      setHasMore(false);
      setIsAdmin(false);
      setSearchText('');
      setActiveSearch(null);
      activeSearchKeyRef.current = getSearchKey(null);
      return Promise.resolve();
    }

    const requestId = latestInitialLoadRef.current + 1;
    latestInitialLoadRef.current = requestId;
    loadingMoreRef.current = false;
    setInitialLoading(true);
    setLoadingMore(false);

    return getMembers(chatId, {
      limit: MEMBERS_PAGE_SIZE,
      q: activeSearch?.q,
      mode: activeSearch?.mode,
    })
      .then((res) => {
        if (latestInitialLoadRef.current !== requestId) {
          return;
        }

        setMembers(res.data.members);
        setNextCursor(res.data.nextCursor);
        setHasMore(res.data.nextCursor != null);
        setIsAdmin(res.data.canManageMembers);
      })
      .catch((err: Error) => {
        if (latestInitialLoadRef.current !== requestId) {
          return;
        }

        showToast(err.message || t`Failed to load members`);
        setMembers([]);
        setNextCursor(null);
        setHasMore(false);
        setIsAdmin(false);
      })
      .finally(() => {
        if (latestInitialLoadRef.current === requestId) {
          setInitialLoading(false);
        }
      });
  }, [activeSearch, chatId, showToast]);

  const loadMoreMembers = useCallback(() => {
    if (!chatId || !hasMore || nextCursor == null || loadingMoreRef.current) {
      return;
    }

    const searchKey = activeSearchKeyRef.current;
    loadingMoreRef.current = true;
    setLoadingMore(true);

    getMembers(chatId, {
      limit: MEMBERS_PAGE_SIZE,
      after: nextCursor,
      q: activeSearch?.q,
      mode: activeSearch?.mode,
    })
      .then((res) => {
        if (activeSearchKeyRef.current !== searchKey) {
          return;
        }

        setMembers((current) => mergeMembers(current, res.data.members));
        setNextCursor(res.data.nextCursor);
        setHasMore(res.data.nextCursor != null);
        setIsAdmin(res.data.canManageMembers);
      })
      .catch((err: Error) => {
        if (activeSearchKeyRef.current !== searchKey) {
          return;
        }

        showToast(err.message || t`Failed to load members`);
      })
      .finally(() => {
        if (activeSearchKeyRef.current === searchKey) {
          loadingMoreRef.current = false;
          setLoadingMore(false);
        }
      });
  }, [activeSearch, chatId, hasMore, nextCursor, showToast]);

  const resetAndReloadMembers = useCallback(() => {
    setMembers([]);
    setNextCursor(null);
    setHasMore(false);
    return loadInitialMembers();
  }, [loadInitialMembers]);

  useEffect(() => {
    loadInitialMembers();
  }, [loadInitialMembers]);

  const handleAddMember = () => {
    presentAlert({
      header: t`Add Member`,
      message: t`Enter user ID to add:`,
      inputs: [{ type: 'number', placeholder: t`User ID` }],
      buttons: [
        { text: t`Cancel`, role: 'cancel' },
        {
          text: t`Add`,
          handler: (data: { 0: string }) => {
            const userId = parseInt(data[0], 10);
            if (isNaN(userId)) {
              showToast(t`Invalid user ID`, 2000);
              return;
            }
            addMember(chatId, { uid: userId })
              .then(() => {
                showToast(t`Member added`, 2000);
                resetAndReloadMembers();
              })
              .catch((err: Error) => {
                showToast(err.message || t`Failed to add member`);
              });
          },
        },
      ],
    });
  };

  const handleRemoveMember = (member: MemberResponse) => {
    const displayName = member.username || t`User ${member.uid}`;
    presentAlert({
      header: t`Remove Member`,
      message: t`Remove ${displayName} from this group?`,
      inputs: [
        { type: 'radio', label: t`Keep messages`, value: 'none', checked: true },
        { type: 'radio', label: t`Delete messages from last 24 hours`, value: 'last24h' },
        { type: 'radio', label: t`Delete all messages`, value: 'all' },
      ],
      buttons: [
        { text: t`Cancel`, role: 'cancel' },
        {
          text: t`Remove`,
          role: 'destructive',
          handler: (value: string) => {
            const deleteMessages = value !== 'none' ? value : undefined;
            removeMember(chatId, member.uid, deleteMessages)
              .then(() => {
                const msg =
                  deleteMessages === 'all'
                    ? t`Member removed, deleting all messages...`
                    : deleteMessages === 'last24h'
                      ? t`Member removed, deleting recent messages...`
                      : t`Member removed`;
                showToast(msg, 2000);
                resetAndReloadMembers();
              })
              .catch((err: Error) => {
                showToast(err.message || t`Failed to remove member`);
              });
          },
        },
      ],
    });
  };

  const handleToggleRole = (member: MemberResponse) => {
    const newRole = member.role === 'admin' ? 'member' : 'admin';
    const isPromoting = newRole === 'admin';
    const displayName = member.username || t`User ${member.uid}`;
    presentAlert({
      header: isPromoting ? t`Promote Member` : t`Demote Member`,
      message: isPromoting ? t`Promote ${displayName} to admin?` : t`Demote ${displayName} to member?`,
      buttons: [
        { text: t`Cancel`, role: 'cancel' },
        {
          text: isPromoting ? t`Promote` : t`Demote`,
          handler: () => {
            updateMemberRole(chatId, member.uid, { role: newRole })
              .then(() => {
                showToast(isPromoting ? t`Member promoted` : t`Member demoted`, 2000);
                resetAndReloadMembers();
              })
              .catch((err: Error) => {
                showToast(err.message || t`Failed to update role`);
              });
          },
        },
      ],
    });
  };

  // Keep references to these functions so they are not flagged as unused.
  // They represent admin actions and will be wired up later.
  void handleRemoveMember;
  void handleToggleRole;

  const renderMembersFooter = useCallback(() => {
    if (loadingMore) {
      return (
        <div className={styles.footerState}>
          <IonSpinner />
        </div>
      );
    }

    if (members.length === 0) {
      return (
        <div className={styles.emptyState}>
          {activeSearch ? <Trans>No matching members found.</Trans> : <Trans>No members found.</Trans>}
        </div>
      );
    }

    return null;
  }, [activeSearch, loadingMore, members.length]);

  return (
    <div className="ion-page">
      <IonHeader>
        <IonToolbar>
          <IonButtons slot="start">{backAction && <BackButton action={backAction} />}</IonButtons>
          <IonTitle className={styles.subtitleToolbar}>
            <div>
              <Trans>Group Members</Trans>
            </div>
            <div className={styles.subtitle}>
              {initialLoading ? (
                <IonSpinner />
              ) : (
                <>
                  <span className={styles.subtitleText}>{members.length}</span>
                  <Plural value={members.length} _1="member" other="members" />
                </>
              )}
            </div>
          </IonTitle>
        </IonToolbar>
        <IonToolbar>
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
            placeholder={t`Search members`}
            showClearButton="focus"
          />
        </IonToolbar>
      </IonHeader>
      <IonContent scrollY={false}>
        {initialLoading ? (
          <div className={styles.loadingState}>
            <IonSpinner />
          </div>
        ) : (
          <div className={styles.layout}>
            <FeatureGate>
              <div className={styles.addMemberAction}>
                <IonButton expand="block" onClick={handleAddMember}>
                  <Trans>Add Member</Trans>
                </IonButton>
              </div>
            </FeatureGate>
            <div className={styles.listContainer}>
              <Virtuoso
                className={`ion-content-scroll-host ${styles.scrollHost}`}
                data={members}
                endReached={hasMore ? () => loadMoreMembers() : undefined}
                components={{ Footer: renderMembersFooter }}
                itemContent={(_, member) => (
                  <ChatMemberRow
                    member={member}
                    isAdmin={isAdmin}
                    isCurrentUser={member.uid === currentUserId}
                    role={member.role}
                    onSelect={(m) => {
                      setProfileSender({
                        uid: m.uid,
                        avatarUrl: m.avatarUrl ?? undefined,
                        name: m.username,
                        gender: m.gender,
                        userGroup: m.userGroup ?? undefined,
                      });
                      setProfileMember(m);
                    }}
                  />
                )}
              />
            </div>
          </div>
        )}
        <UserProfileModal
          sender={profileSender}
          onDismiss={() => {
            setProfileSender(null);
            setProfileMember(null);
          }}
          chatId={chatId}
          canManage={isAdmin}
          member={profileMember}
          onActionComplete={resetAndReloadMembers}
        />
      </IonContent>
    </div>
  );
}

export function ChatMembersPage() {
  const { id } = useParams<{ id: string }>();
  return (
    <IonPage>
      <ChatMembersCore chatId={id} backAction={{ type: 'back', defaultHref: `/chats/chat/${id}` }} />
    </IonPage>
  );
}
