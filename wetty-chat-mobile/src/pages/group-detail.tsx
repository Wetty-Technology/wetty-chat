import { useEffect, useState } from 'react';
import {
  IonButtons,
  IonContent,
  IonHeader,
  IonItem,
  IonLabel,
  IonList,
  IonPage,
  IonSpinner,
  IonTitle,
  IonToolbar,
  useIonAlert,
  useIonToast,
} from '@ionic/react';
import { useParams } from 'react-router-dom';
import { useDispatch } from 'react-redux';
import { addMember, getGroupInfo, getMembers, type GroupInfoResponse, type MemberResponse } from '@/api/group';
import { FeatureGate } from '@/components/FeatureGate';
import { BackButton } from '@/components/BackButton';
import type { BackAction } from '@/types/back-action';
import { setChatMeta } from '@/store/chatsSlice';

function groupDisplayName(detail: GroupInfoResponse | null, id: string): string {
  if (detail?.name?.trim()) return detail.name.trim();
  return `Chat ${id}`;
}

function avatarUrl(detail: GroupInfoResponse | null): string | null {
  if (detail?.avatar?.trim()) return detail.avatar.trim();
  return null;
}

function initials(detail: GroupInfoResponse | null): string {
  const name = detail?.name?.trim();
  if (name && name.length > 0) return name.charAt(0).toUpperCase();
  return '?';
}

interface GroupDetailCoreProps {
  chatId?: string;
  backAction?: BackAction;
}

function GroupDetailSession({ id, backAction }: { id: string; backAction?: BackAction }) {
  const dispatch = useDispatch();
  const [presentToast] = useIonToast();
  const [presentAlert] = useIonAlert();

  const [detail, setDetail] = useState<GroupInfoResponse | null>(null);
  const [members, setMembers] = useState<MemberResponse[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    Promise.all([getGroupInfo(id), getMembers(id, { limit: 20 })])
      .then(([chatRes, membersRes]) => {
        setDetail(chatRes.data);
        const { id: groupId, ...meta } = chatRes.data;
        void groupId;
        dispatch(setChatMeta({ chatId: id, meta }));
        setMembers(membersRes.data.members ?? []);
      })
      .catch((err: Error) => {
        const msg = err?.message ?? 'Failed to load group';
        setError(msg);
        presentToast({ message: msg, duration: 3000 });
      })
      .finally(() => setLoading(false));
  }, [dispatch, id, presentToast]);

  const refreshMembers = () => {
    getMembers(id, { limit: 20 })
      .then((res) => setMembers(res.data.members ?? []))
      .catch((err: Error) => {
        presentToast({ message: err?.message ?? 'Failed to refresh members', duration: 3000 });
      });
  };

  const handleAddMember = () => {
    presentAlert({
      header: 'Add Member',
      message: 'Enter the user ID (uid) to add as a member:',
      inputs: [{ type: 'number', placeholder: 'User ID' }],
      buttons: [
        { text: 'Cancel', role: 'cancel' },
        {
          text: 'Add',
          handler: (data: { 0: string }) => {
            const value = data[0];
            if (value == null || String(value).trim() === '') return;
            const uid = parseInt(String(value).trim(), 10);
            if (Number.isNaN(uid) || uid < 1) {
              presentToast({ message: 'Please enter a valid user ID (positive number).', duration: 3000 });
              return;
            }
            addMember(id, { uid })
              .then(() => {
                presentToast({ message: 'Member added.', duration: 2000 });
                refreshMembers();
              })
              .catch((err: Error & { response?: { status?: number } }) => {
                const msg =
                  err?.response?.status === 409
                    ? 'User is already a member.'
                    : err?.response?.status === 404
                      ? 'User or chat not found.'
                      : (err?.message ?? 'Failed to add member');
                presentToast({ message: msg, duration: 3000 });
              });
          },
        },
      ],
    });
  };

  if (!id) {
    return (
      <div className="ion-page">
        <IonHeader>
          <IonToolbar>
            <IonButtons slot="start">{backAction && <BackButton action={backAction} />}</IonButtons>
            <IonTitle>Group</IonTitle>
          </IonToolbar>
        </IonHeader>
        <IonContent>
          <div style={{ padding: '16px' }}>Invalid group.</div>
        </IonContent>
      </div>
    );
  }

  const avatar = avatarUrl(detail);
  const displayName = groupDisplayName(detail, id);

  return (
    <div className="ion-page">
      <IonHeader>
        <IonToolbar>
          <IonButtons slot="start">{backAction && <BackButton action={backAction} />}</IonButtons>
          <IonTitle>Group</IonTitle>
        </IonToolbar>
      </IonHeader>
      <IonContent>
        {loading ? (
          <div style={{ display: 'flex', justifyContent: 'center', padding: '24px' }}>
            <IonSpinner />
          </div>
        ) : error ? (
          <div style={{ padding: '16px' }}>{error}</div>
        ) : (
          <>
            <div style={{ padding: '16px' }}>
              <h3 style={{ margin: '0 0 4px' }}>Group name</h3>
              <p style={{ margin: 0 }}>{displayName}</p>
            </div>
            <div style={{ padding: '16px' }}>
              <h3 style={{ margin: '0 0 8px' }}>Group avatar</h3>
              {avatar ? (
                <img src={avatar} alt="" style={{ width: 64, height: 64, borderRadius: '50%', objectFit: 'cover' }} />
              ) : (
                <div
                  style={{
                    width: 64,
                    height: 64,
                    borderRadius: '50%',
                    background: 'var(--ion-color-medium)',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    fontSize: 28,
                    fontWeight: 500,
                    color: 'var(--ion-color-primary)',
                  }}
                >
                  {initials(detail)}
                </div>
              )}
            </div>
            <div style={{ padding: '16px' }}>
              <h3 style={{ margin: '0 0 4px' }}>Group notes</h3>
              {detail?.description?.trim() ? (
                <p style={{ margin: 0 }}>{detail.description.trim()}</p>
              ) : (
                <p style={{ margin: 0, color: 'var(--ion-color-medium)' }}>No notes.</p>
              )}
            </div>
            <div style={{ padding: '16px 16px 0' }}>
              <h3 style={{ margin: '0 0 8px' }}>Members</h3>
            </div>
            <IonList>
              <FeatureGate>
                <IonItem button onClick={handleAddMember}>
                  <IonLabel color="primary">Add Member</IonLabel>
                </IonItem>
              </FeatureGate>
              {members.map((m) => (
                <IonItem key={m.uid}>
                  <IonLabel>
                    <h2>{m.username ?? `User ${m.uid}`}</h2>
                  </IonLabel>
                  <IonLabel slot="end" color="medium">
                    {m.role}
                  </IonLabel>
                </IonItem>
              ))}
            </IonList>
          </>
        )}
      </IonContent>
    </div>
  );
}

export default function GroupDetailCore({ chatId: propChatId, backAction }: GroupDetailCoreProps) {
  const { id: paramId } = useParams<{ id: string }>();
  const id = propChatId ?? paramId;

  if (!id) {
    return (
      <div className="ion-page">
        <IonHeader>
          <IonToolbar>
            <IonButtons slot="start">{backAction && <BackButton action={backAction} />}</IonButtons>
            <IonTitle>Group</IonTitle>
          </IonToolbar>
        </IonHeader>
        <IonContent>
          <div style={{ padding: '16px' }}>Invalid group.</div>
        </IonContent>
      </div>
    );
  }

  return <GroupDetailSession key={id} id={id} backAction={backAction} />;
}

export function GroupDetailPage() {
  const { id } = useParams<{ id: string }>();
  return (
    <IonPage>
      <GroupDetailCore chatId={id} backAction={{ type: 'back', defaultHref: `/chats/chat/${id}` }} />
    </IonPage>
  );
}
