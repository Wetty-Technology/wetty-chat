import { useCallback, useEffect, useMemo, useState } from 'react';
import {
  IonButton,
  IonButtons,
  IonContent,
  IonHeader,
  IonIcon,
  IonPage,
  IonSpinner,
  IonTitle,
  IonToolbar,
  useIonAlert,
  useIonToast,
} from '@ionic/react';
import { copyOutline } from 'ionicons/icons';
import { t } from '@lingui/core/macro';
import { useParams } from 'react-router-dom';
import { Trans } from '@lingui/react/macro';
import { useSelector } from 'react-redux';
import { deleteInvite, getInvites, sendInviteMessage, type InviteInfoResponse, type InviteType } from '@/api/invites';
import { BackButton } from '@/components/BackButton';
import { ShareInviteGroupSelectorModal } from '@/components/chat/settings/ShareInviteGroupSelectorModal';
import {
  canCopyInviteCode,
  copyInviteCode,
  createInviteMessageClientGeneratedId,
} from '@/components/chat/settings/shareInviteHelpers';
import { getChatDisplayName } from '@/utils/chatDisplay';
import type { GroupSelectorItem } from '@/api/group';
import { selectEffectiveLocale } from '@/store/settingsSlice';
import type { RootState } from '@/store';
import type { BackAction } from '@/types/back-action';
import styles from './manage-invites.module.scss';

interface ChatInvitesCoreProps {
  chatId?: string;
  backAction?: BackAction;
}

type PendingAction = 'share' | 'revoke' | null;

function isInviteActive(invite: InviteInfoResponse): boolean {
  if (invite.revoked_at) {
    return false;
  }

  if (!invite.expires_at) {
    return true;
  }

  return new Date(invite.expires_at).getTime() > Date.now();
}

function getInviteTypeLabel(inviteType: InviteType): string {
  switch (inviteType) {
    case 'membership':
      return t`Membership`;
    case 'targeted':
      return t`Targeted`;
    case 'generic':
    default:
      return t`Public`;
  }
}

function formatExpiry(locale: string, expiresAt: string | null): string {
  if (!expiresAt) {
    return t`Never`;
  }

  const date = new Date(expiresAt);
  if (Number.isNaN(date.getTime())) {
    return expiresAt;
  }

  const now = new Date();
  const isSameYear = date.getFullYear() === now.getFullYear();

  return Intl.DateTimeFormat(locale, {
    ...(isSameYear ? {} : { year: 'numeric' }),
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: '2-digit',
  }).format(date);
}

interface InviteCardProps {
  invite: InviteInfoResponse;
  locale: string;
  restrictedGroupName: string | null;
  pendingAction: PendingAction;
  onCopy: (invite: InviteInfoResponse) => void;
  onShare: (invite: InviteInfoResponse) => void;
  onRevoke: (invite: InviteInfoResponse) => void;
}

function InviteCard({
  invite,
  locale,
  restrictedGroupName,
  pendingAction,
  onCopy,
  onShare,
  onRevoke,
}: InviteCardProps) {
  const disableShare = pendingAction !== null;
  const disableRevoke = pendingAction !== null;

  return (
    <section className={styles.card}>
      <div className={styles.cardRow}>
        <div className={styles.codeBlock}>
          <span className={styles.rowLabel}>
            <Trans>Invite Code</Trans>
          </span>
          <span className={styles.inviteCode}>{invite.code}</span>
        </div>
        <IonButton
          fill="clear"
          size="small"
          className={styles.copyButton}
          disabled={!canCopyInviteCode()}
          onClick={() => onCopy(invite)}
          aria-label={t`Copy code`}
        >
          <IonIcon slot="icon-only" icon={copyOutline} />
        </IonButton>
      </div>

      <div className={`${styles.cardRow} ${styles.metaRow}`}>
        <div className={styles.metaItem}>
          <span className={styles.rowLabel}>
            <Trans>Invite Type</Trans>
          </span>
          <span className={styles.metaValue}>{getInviteTypeLabel(invite.invite_type)}</span>
        </div>
        {invite.invite_type === 'membership' && restrictedGroupName ? (
          <div className={styles.metaItem}>
            <span className={styles.rowLabel}>
              <Trans>Restricted To</Trans>
            </span>
            <span className={styles.metaValue}>{restrictedGroupName}</span>
          </div>
        ) : null}
        <div className={styles.metaItem}>
          <span className={styles.rowLabel}>
            <Trans>Expire Date</Trans>
          </span>
          <span className={styles.metaValue}>{formatExpiry(locale, invite.expires_at)}</span>
        </div>
      </div>

      <div className={`${styles.cardRow} ${styles.actionsRow}`}>
        <IonButton
          expand="block"
          className={styles.actionButton}
          disabled={disableShare}
          onClick={() => onShare(invite)}
        >
          {pendingAction === 'share' ? <IonSpinner name="crescent" /> : <Trans>Share</Trans>}
        </IonButton>
        <IonButton
          expand="block"
          color="danger"
          className={styles.actionButton}
          disabled={disableRevoke}
          onClick={() => onRevoke(invite)}
        >
          {pendingAction === 'revoke' ? <IonSpinner name="crescent" /> : <Trans>Revoke</Trans>}
        </IonButton>
      </div>
    </section>
  );
}

interface ChatInvitesContentProps {
  invites: InviteInfoResponse[];
  locale: string;
  loading: boolean;
  error: string | null;
  pendingInviteId: string | null;
  pendingAction: PendingAction;
  onCopy: (invite: InviteInfoResponse) => void;
  onShare: (invite: InviteInfoResponse) => void;
  onRevoke: (invite: InviteInfoResponse) => void;
}

function ChatInvitesContent({
  invites,
  locale,
  loading,
  error,
  pendingInviteId,
  pendingAction,
  onCopy,
  onShare,
  onRevoke,
}: ChatInvitesContentProps) {
  const chatsById = useSelector((state: RootState) => state.chats.byId);

  if (loading) {
    return (
      <div className={styles.centerState}>
        <IonSpinner />
      </div>
    );
  }

  if (error) {
    return <div className={styles.emptyState}>{error}</div>;
  }

  if (invites.length === 0) {
    return (
      <div className={styles.emptyState}>
        <Trans>No active invite links created by you.</Trans>
      </div>
    );
  }

  return (
    <div className={styles.content}>
      {invites.map((invite) => (
        <InviteCard
          key={invite.id}
          invite={invite}
          locale={locale}
          restrictedGroupName={
            invite.required_chat_id
              ? getChatDisplayName(invite.required_chat_id, chatsById[invite.required_chat_id]?.details.name)
              : null
          }
          pendingAction={pendingInviteId === invite.id ? pendingAction : null}
          onCopy={onCopy}
          onShare={onShare}
          onRevoke={onRevoke}
        />
      ))}
    </div>
  );
}

export default function ChatInvitesCore({ chatId: propChatId, backAction }: ChatInvitesCoreProps) {
  const { id } = useParams<{ id: string }>();
  const chatId = propChatId ?? (id ? String(id) : '');
  const locale = useSelector(selectEffectiveLocale);
  const currentUserId = useSelector((state: RootState) => state.user.uid);
  const [presentToast] = useIonToast();
  const [presentAlert] = useIonAlert();
  const [invites, setInvites] = useState<InviteInfoResponse[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [pendingInviteId, setPendingInviteId] = useState<string | null>(null);
  const [pendingAction, setPendingAction] = useState<PendingAction>(null);
  const [selectedInvite, setSelectedInvite] = useState<InviteInfoResponse | null>(null);
  const [selectorOpen, setSelectorOpen] = useState(false);

  const loadInvites = useCallback(async () => {
    setLoading(true);

    try {
      const response = await getInvites({ group_id: chatId });
      const filteredInvites = response.data.invites.filter(
        (invite) => invite.chat_id === chatId && invite.creator_uid === currentUserId && isInviteActive(invite),
      );
      setInvites(filteredInvites);
      setError(null);
    } catch (err) {
      const message = err instanceof Error ? err.message : t`Failed to load invite links`;
      setError(message);
    } finally {
      setLoading(false);
    }
  }, [chatId, currentUserId]);

  useEffect(() => {
    void loadInvites();
  }, [loadInvites]);

  const sortedInvites = useMemo(
    () =>
      [...invites].sort((left, right) => {
        const leftTs = new Date(left.created_at).getTime();
        const rightTs = new Date(right.created_at).getTime();
        return rightTs - leftTs;
      }),
    [invites],
  );

  const handleCopy = useCallback(
    async (invite: InviteInfoResponse) => {
      if (!canCopyInviteCode()) {
        presentToast({ message: t`Clipboard is not available on this device`, duration: 2500 });
        return;
      }

      try {
        await copyInviteCode(invite);
        presentToast({ message: t`Invite code copied`, duration: 2000 });
      } catch {
        presentToast({ message: t`Failed to copy invite code`, duration: 2500 });
      }
    },
    [presentToast],
  );

  const handleShare = useCallback((invite: InviteInfoResponse) => {
    setSelectedInvite(invite);
    setSelectorOpen(true);
  }, []);

  const closeSelector = useCallback(() => {
    if (pendingAction === 'share') {
      return;
    }

    setSelectorOpen(false);
    setSelectedInvite(null);
  }, [pendingAction]);

  const handleShareSelect = useCallback(
    async (group: GroupSelectorItem) => {
      if (!selectedInvite) {
        return;
      }

      setPendingInviteId(selectedInvite.id);
      setPendingAction('share');

      try {
        await sendInviteMessage({
          source_chat_id: chatId,
          destination_chat_id: group.id,
          invite_id: selectedInvite.id,
          client_generated_id: createInviteMessageClientGeneratedId(),
        });

        presentToast({
          message: t`Invite sent to ${getChatDisplayName(group.id, group.name)}`,
          duration: 2500,
        });
        setSelectorOpen(false);
        setSelectedInvite(null);
      } catch (err) {
        const message = err instanceof Error ? err.message : t`Failed to send invite`;
        presentToast({ message, duration: 3000 });
      } finally {
        setPendingInviteId(null);
        setPendingAction(null);
      }
    },
    [chatId, presentToast, selectedInvite],
  );

  const revokeInvite = useCallback(
    async (invite: InviteInfoResponse) => {
      setPendingInviteId(invite.id);
      setPendingAction('revoke');

      try {
        await deleteInvite(invite.id);
        setInvites((current) => current.filter((entry) => entry.id !== invite.id));
        presentToast({ message: t`Invite revoked`, duration: 2000 });
      } catch (err) {
        const message = err instanceof Error ? err.message : t`Failed to revoke invite`;
        presentToast({ message, duration: 3000 });
      } finally {
        setPendingInviteId(null);
        setPendingAction(null);
      }
    },
    [presentToast],
  );

  const handleRevoke = useCallback(
    (invite: InviteInfoResponse) => {
      presentAlert({
        header: t`Revoke invite`,
        message: t`This invite link will stop working immediately.`,
        buttons: [
          { text: t`Cancel`, role: 'cancel' },
          {
            text: t`Revoke`,
            role: 'destructive',
            handler: () => {
              void revokeInvite(invite);
            },
          },
        ],
      });
    },
    [presentAlert, revokeInvite],
  );

  if (!chatId) {
    return null;
  }

  return (
    <IonPage>
      <IonHeader>
        <IonToolbar>
          <IonButtons slot="start">{backAction && <BackButton action={backAction} />}</IonButtons>
          <IonTitle>
            <Trans>Manage Invite Links</Trans>
          </IonTitle>
        </IonToolbar>
      </IonHeader>
      <IonContent color="light">
        <ChatInvitesContent
          invites={sortedInvites}
          locale={locale}
          loading={loading}
          error={error}
          pendingInviteId={pendingInviteId}
          pendingAction={pendingAction}
          onCopy={(invite) => void handleCopy(invite)}
          onShare={handleShare}
          onRevoke={handleRevoke}
        />
        <ShareInviteGroupSelectorModal
          isOpen={selectorOpen}
          isDesktop={false}
          scope="joined"
          onDismiss={closeSelector}
          onSelect={(group) => void handleShareSelect(group)}
        />
      </IonContent>
    </IonPage>
  );
}

export function ChatInvitesPage() {
  const { id } = useParams<{ id: string }>();
  return <ChatInvitesCore chatId={id} backAction={{ type: 'back', defaultHref: `/chats/chat/${id}/settings` }} />;
}
