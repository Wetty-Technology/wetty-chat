import React, { useState, useEffect } from 'react';
import {
  f7,
  Page,
  Navbar,
  List,
  ListItem,
  Block,
  Button,
  Chip,
} from 'framework7-react';
import { getMembers, addMember, removeMember, updateMemberRole, type MemberResponse } from '@/api/chats';
import { getCurrentUserId } from '@/js/current-user';

interface Props {
  f7route?: {
    params: Record<string, string>;
  };
}

export default function ChatMembersPage({ f7route }: Props) {
  const { id } = f7route?.params || {};
  const chatId = id ? String(id) : '';
  const currentUserId = getCurrentUserId();

  const [members, setMembers] = useState<MemberResponse[]>([]);
  const [loading, setLoading] = useState(true);
  const [isAdmin, setIsAdmin] = useState(false);

  const loadMembers = () => {
    if (!chatId) return;
    setLoading(true);
    getMembers(chatId)
      .then((res) => {
        setMembers(res.data);
        const currentMember = res.data.find((m) => m.uid === currentUserId);
        setIsAdmin(currentMember?.role === 'admin');
      })
      .catch((err: Error) => {
        f7.toast.create({ text: err.message || 'Failed to load members', closeTimeout: 3000 }).open();
      })
      .finally(() => setLoading(false));
  };

  useEffect(() => {
    loadMembers();
  }, [chatId]);

  const handleAddMember = () => {
    f7.dialog.prompt('Enter user ID to add:', (uid: string) => {
      const userId = parseInt(uid, 10);
      if (isNaN(userId)) {
        f7.toast.create({ text: 'Invalid user ID', closeTimeout: 2000 }).open();
        return;
      }
      addMember(chatId, { uid: userId })
        .then(() => {
          f7.toast.create({ text: 'Member added', closeTimeout: 2000 }).open();
          loadMembers();
        })
        .catch((err: Error) => {
          f7.toast.create({ text: err.message || 'Failed to add member', closeTimeout: 3000 }).open();
        });
    });
  };

  const handleRemoveMember = (member: MemberResponse) => {
    f7.dialog.confirm(
      `Remove ${member.username || `User ${member.uid}`} from this group?`,
      () => {
        removeMember(chatId, member.uid)
          .then(() => {
            f7.toast.create({ text: 'Member removed', closeTimeout: 2000 }).open();
            loadMembers();
          })
          .catch((err: Error) => {
            f7.toast.create({ text: err.message || 'Failed to remove member', closeTimeout: 3000 }).open();
          });
      }
    );
  };

  const handleToggleRole = (member: MemberResponse) => {
    const newRole = member.role === 'admin' ? 'member' : 'admin';
    const action = newRole === 'admin' ? 'Promote' : 'Demote';
    f7.dialog.confirm(
      `${action} ${member.username || `User ${member.uid}`} to ${newRole}?`,
      () => {
        updateMemberRole(chatId, member.uid, { role: newRole })
          .then(() => {
            f7.toast.create({ text: `Member ${action.toLowerCase()}d`, closeTimeout: 2000 }).open();
            loadMembers();
          })
          .catch((err: Error) => {
            f7.toast.create({ text: err.message || 'Failed to update role', closeTimeout: 3000 }).open();
          });
      }
    );
  };

  const handleLeaveGroup = () => {
    f7.dialog.confirm('Are you sure you want to leave this group?', () => {
      removeMember(chatId, currentUserId)
        .then(() => {
          f7.toast.create({ text: 'Left group', closeTimeout: 2000 }).open();
          f7.views.main.router.navigate('/chats/', { reloadCurrent: true });
        })
        .catch((err: Error) => {
          f7.toast.create({ text: err.message || 'Failed to leave group', closeTimeout: 3000 }).open();
        });
    });
  };

  return (
    <Page>
      <Navbar title="Group Members" backLink />
      {loading ? (
        <Block>Loading...</Block>
      ) : (
        <>
          {isAdmin && (
            <Block>
              <Button fill onClick={handleAddMember}>
                Add Member
              </Button>
            </Block>
          )}
          <List>
            {members.map((member) => (
              <ListItem
                key={member.uid}
                title={member.username || `User ${member.uid}`}
                after={
                  <Chip
                    text={member.role}
                    color={member.role === 'admin' ? 'blue' : 'gray'}
                  />
                }
                onClick={() => {
                  if (!isAdmin || member.uid === currentUserId) return;
                  const buttons = [
                    [
                      {
                        text: member.role === 'admin' ? 'Demote to Member' : 'Promote to Admin',
                        onClick: () => handleToggleRole(member),
                      },
                      {
                        text: 'Remove from Group',
                        color: 'red',
                        onClick: () => handleRemoveMember(member),
                      },
                    ],
                    [
                      {
                        text: 'Cancel',
                        color: 'gray',
                      },
                    ],
                  ];
                  f7.actions.create({ buttons }).open();
                }}
              />
            ))}
          </List>
          <Block>
            <Button fill color="red" onClick={handleLeaveGroup}>
              Leave Group
            </Button>
          </Block>
        </>
      )}
    </Page>
  );
}
