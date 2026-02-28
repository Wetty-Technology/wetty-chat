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
  IonBackButton,
  IonButtons,
  IonSpinner,
  useIonToast,
  useIonAlert,
  useIonActionSheet,
} from '@ionic/react';
import { useParams, useHistory } from 'react-router-dom';
import { getMembers, addMember, removeMember, updateMemberRole, type MemberResponse } from '@/api/chats';
import { getCurrentUserId } from '@/js/current-user';

export default function ChatMembersPage() {
  const { id } = useParams<{ id: string }>();
  const chatId = id ? String(id) : '';
  const history = useHistory();
  const currentUserId = getCurrentUserId();

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
        showToast(err.message || 'Failed to load members');
      })
      .finally(() => setLoading(false));
  }, [chatId, currentUserId, showToast]);

  useEffect(() => {
    loadMembers();
  }, [loadMembers]);

  const handleAddMember = () => {
    presentAlert({
      header: 'Add Member',
      message: 'Enter user ID to add:',
      inputs: [{ type: 'number', placeholder: 'User ID' }],
      buttons: [
        { text: 'Cancel', role: 'cancel' },
        {
          text: 'Add',
          handler: (data: { 0: string }) => {
            const userId = parseInt(data[0], 10);
            if (isNaN(userId)) {
              showToast('Invalid user ID', 2000);
              return;
            }
            addMember(chatId, { uid: userId })
              .then(() => {
                showToast('Member added', 2000);
                loadMembers();
              })
              .catch((err: Error) => {
                showToast(err.message || 'Failed to add member');
              });
          },
        },
      ],
    });
  };

  const handleRemoveMember = (member: MemberResponse) => {
    presentAlert({
      header: 'Remove Member',
      message: `Remove ${member.username || `User ${member.uid}`} from this group?`,
      buttons: [
        { text: 'Cancel', role: 'cancel' },
        {
          text: 'Remove',
          role: 'destructive',
          handler: () => {
            removeMember(chatId, member.uid)
              .then(() => {
                showToast('Member removed', 2000);
                loadMembers();
              })
              .catch((err: Error) => {
                showToast(err.message || 'Failed to remove member');
              });
          },
        },
      ],
    });
  };

  const handleToggleRole = (member: MemberResponse) => {
    const newRole = member.role === 'admin' ? 'member' : 'admin';
    const action = newRole === 'admin' ? 'Promote' : 'Demote';
    presentAlert({
      header: `${action} Member`,
      message: `${action} ${member.username || `User ${member.uid}`} to ${newRole}?`,
      buttons: [
        { text: 'Cancel', role: 'cancel' },
        {
          text: action,
          handler: () => {
            updateMemberRole(chatId, member.uid, { role: newRole })
              .then(() => {
                showToast(`Member ${action.toLowerCase()}d`, 2000);
                loadMembers();
              })
              .catch((err: Error) => {
                showToast(err.message || 'Failed to update role');
              });
          },
        },
      ],
    });
  };

  const handleLeaveGroup = () => {
    presentAlert({
      header: 'Leave Group',
      message: 'Are you sure you want to leave this group?',
      buttons: [
        { text: 'Cancel', role: 'cancel' },
        {
          text: 'Leave',
          role: 'destructive',
          handler: () => {
            removeMember(chatId, currentUserId)
              .then(() => {
                showToast('Left group', 2000);
                history.replace('/chats');
              })
              .catch((err: Error) => {
                showToast(err.message || 'Failed to leave group');
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
          text: member.role === 'admin' ? 'Demote to Member' : 'Promote to Admin',
          handler: () => handleToggleRole(member),
        },
        {
          text: 'Remove from Group',
          role: 'destructive',
          handler: () => handleRemoveMember(member),
        },
        { text: 'Cancel', role: 'cancel' },
      ],
    });
  };

  return (
    <IonPage>
      <IonHeader>
        <IonToolbar>
          <IonButtons slot="start">
            <IonBackButton defaultHref={`/chats/${chatId}`} text="" />
          </IonButtons>
          <IonTitle>Group Members</IonTitle>
        </IonToolbar>
      </IonHeader>
      <IonContent>
        {loading ? (
          <div style={{ display: 'flex', justifyContent: 'center', padding: '24px' }}>
            <IonSpinner />
          </div>
        ) : (
          <>
            {isAdmin && (
              <div style={{ padding: '16px' }}>
                <IonButton expand="block" onClick={handleAddMember}>
                  Add Member
                </IonButton>
              </div>
            )}
            <IonList>
              {members.map((member) => (
                <IonItem
                  key={member.uid}
                  button={isAdmin && member.uid !== currentUserId}
                  detail={false}
                  onClick={() => handleMemberTap(member)}
                >
                  <IonLabel>
                    {member.username || `User ${member.uid}`}
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
            <div style={{ padding: '16px' }}>
              <IonButton expand="block" color="danger" onClick={handleLeaveGroup}>
                Leave Group
              </IonButton>
            </div>
          </>
        )}
      </IonContent>
    </IonPage>
  );
}
