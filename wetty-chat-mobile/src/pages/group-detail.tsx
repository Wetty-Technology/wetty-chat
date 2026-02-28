import { useState, useEffect } from 'react';
import {
  IonPage,
  IonHeader,
  IonToolbar,
  IonTitle,
  IonContent,
  IonList,
  IonItem,
  IonLabel,
  IonBackButton,
  IonButtons,
  IonSpinner,
  useIonToast,
  useIonAlert,
} from '@ionic/react';
import { useParams } from 'react-router-dom';
import { getChat, type ChatDetail } from '@/api/chats';
import { getMembers, addMember, type MemberResponse } from '@/api/members';

function groupDisplayName(detail: ChatDetail | null, id: string): string {
  if (detail?.name?.trim()) return detail.name.trim();
  return `Chat ${id}`;
}

function avatarUrl(detail: ChatDetail | null): string | null {
  if (detail?.avatar?.trim()) return detail.avatar.trim();
  return null;
}

function initials(detail: ChatDetail | null): string {
  const name = detail?.name?.trim();
  if (name && name.length > 0) return name.charAt(0).toUpperCase();
  return '?';
}

export default function GroupDetail() {
  const { id } = useParams<{ id: string }>();
  const [presentToast] = useIonToast();
  const [presentAlert] = useIonAlert();

  const [detail, setDetail] = useState<ChatDetail | null>(null);
  const [members, setMembers] = useState<MemberResponse[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!id) return;
    setLoading(true);
    setError(null);
    Promise.all([getChat(id), getMembers(id)])
      .then(([chatRes, membersRes]) => {
        setDetail(chatRes.data);
        setMembers(membersRes.data ?? []);
      })
      .catch((err: Error) => {
        const msg = err?.message ?? 'Failed to load group';
        setError(msg);
        presentToast({ message: msg, duration: 3000 });
      })
      .finally(() => setLoading(false));
  }, [id, presentToast]);

  const refreshMembers = () => {
    getMembers(id)
      .then((res) => setMembers(res.data ?? []))
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
            addMember(id, uid)
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
                      : err?.message ?? 'Failed to add member';
                presentToast({ message: msg, duration: 3000 });
              });
          },
        },
      ],
    });
  };

  if (!id) {
    return (
      <IonPage>
        <IonHeader>
          <IonToolbar>
            <IonButtons slot="start">
              <IonBackButton defaultHref="/chats" text="" />
            </IonButtons>
            <IonTitle>Group</IonTitle>
          </IonToolbar>
        </IonHeader>
        <IonContent>
          <div style={{ padding: '16px' }}>Invalid group.</div>
        </IonContent>
      </IonPage>
    );
  }

  const avatar = avatarUrl(detail);
  const displayName = groupDisplayName(detail, id);

  return (
    <IonPage>
      <IonHeader>
        <IonToolbar>
          <IonButtons slot="start">
            <IonBackButton defaultHref="/chats" text="" />
          </IonButtons>
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
                <img
                  src={avatar}
                  alt=""
                  style={{ width: 64, height: 64, borderRadius: '50%', objectFit: 'cover' }}
                />
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
              <IonItem button onClick={handleAddMember}>
                <IonLabel color="primary">Add Member</IonLabel>
              </IonItem>
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
    </IonPage>
  );
}
