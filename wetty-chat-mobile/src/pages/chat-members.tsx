import { useState, useEffect, useCallback } from 'react';
import {
  IonPage,
  IonHeader,
  IonToolbar,
  IonTitle,
  IonContent,
  IonList,
  IonItem,
  IonLabel,
  IonChip,
  IonButton,
  IonButtons,
  IonSpinner,
  useIonToast,
  useIonAlert,
  useIonActionSheet,
} from '@ionic/react';
import { useParams } from 'react-router-dom';
import { t } from '@lingui/core/macro';
import { Trans } from '@lingui/react/macro';
import { getMembers, addMember, removeMember, updateMemberRole, type MemberResponse } from '@/api/group';
import { useSelector } from 'react-redux';
import type { RootState } from '@/store/index';
import { FeatureGate } from '@/components/FeatureGate';
import { BackButton } from '@/components/BackButton';
import type { BackAction } from '@/types/back-action';

interface ChatMembersCoreProps {
  chatId?: string;
  backAction?: BackAction;
}

export default function ChatMembersCore({ chatId: propChatId, backAction }: ChatMembersCoreProps) {
  const { id } = useParams<{ id: string }>();
  const chatId = propChatId ?? (id ? String(id) : '');
  const currentUserId = useSelector((state: RootState) => state.user.uid);

  const [presentToast] = useIonToast();
  const [presentAlert] = useIonAlert();
  const [presentActionSheet] = useIonActionSheet();

  const [members, setMembers] = useState<MemberResponse[]>([]);
  const [loading, setLoading] = useState(true);
  const [isAdmin, setIsAdmin] = useState(false);

  const showToast = useCallback((msg: string, duration = 3000) => {
    presentToast({ message: msg, duration });
  }, [presentToast]);

  const loadMembers = useCallback(() => {
    if (!chatId) return;
    setLoading(true);
    getMembers(chatId)
      .then((res) => {
        setMembers(res.data);
        const currentMember = res.data.find((m) => m.uid === currentUserId);
        setIsAdmin(currentMember?.role === 'admin');
      })
      .catch((err: Error) => {
        showToast(err.message || t`Failed to load members`);
      })
      .finally(() => setLoading(false));
  }, [chatId, currentUserId, showToast]);

  useEffect(() => {
    loadMembers();
  }, [loadMembers]);

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
                loadMembers();
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
      buttons: [
        { text: t`Cancel`, role: 'cancel' },
        {
          text: t`Remove`,
          role: 'destructive',
          handler: () => {
            removeMember(chatId, member.uid)
              .then(() => {
                showToast(t`Member removed`, 2000);
                loadMembers();
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
      message: isPromoting
        ? t`Promote ${displayName} to admin?`
        : t`Demote ${displayName} to member?`,
      buttons: [
        { text: t`Cancel`, role: 'cancel' },
        {
          text: isPromoting ? t`Promote` : t`Demote`,
          handler: () => {
            updateMemberRole(chatId, member.uid, { role: newRole })
              .then(() => {
                showToast(isPromoting ? t`Member promoted` : t`Member demoted`, 2000);
                loadMembers();
              })
              .catch((err: Error) => {
                showToast(err.message || t`Failed to update role`);
              });
          },
        },
      ],
    });
  };

  const handleMemberTap = (member: MemberResponse) => {
    if (!isAdmin || member.uid === currentUserId) return;
    presentActionSheet({
      buttons: [
        {
          text: member.role === 'admin' ? t`Demote to Member` : t`Promote to Admin`,
          handler: () => handleToggleRole(member),
        },
        {
          text: t`Remove from Group`,
          role: 'destructive',
          handler: () => handleRemoveMember(member),
        },
        { text: t`Cancel`, role: 'cancel' },
      ],
    });
  };

  return (
    <div className="ion-page">
      <IonHeader>
        <IonToolbar>
          <IonButtons slot="start">
            {backAction && <BackButton action={backAction} />}
          </IonButtons>
          <IonTitle><Trans>Group Members</Trans></IonTitle>
        </IonToolbar>
      </IonHeader>
      <IonContent>
        {loading ? (
          <div style={{ display: 'flex', justifyContent: 'center', padding: '24px' }}>
            <IonSpinner />
          </div>
        ) : (
          <>
            <FeatureGate>
              <div style={{ padding: '16px' }}>
                <IonButton expand="block" onClick={handleAddMember}>
                  <Trans>Add Member</Trans>
                </IonButton>
              </div>
            </FeatureGate>
            <IonList>
              {members.map((member) => (
                <IonItem
                  key={member.uid}
                  button={isAdmin && member.uid !== currentUserId}
                  detail={false}
                  onClick={() => import.meta.env.DEV && handleMemberTap(member)}
                >
                  <IonLabel>
                    {member.username || t`User ${member.uid}`}
                  </IonLabel>
                  <IonChip
                    color={member.role === 'admin' ? 'primary' : 'medium'}
                    slot="end"
                  >
                    {member.role}
                  </IonChip>
                </IonItem>
              ))}
            </IonList>
          </>
        )}
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
