import React, { useState, useEffect } from 'react';
import { f7, Page, Navbar, Block, BlockTitle, List, ListItem, ListButton } from 'framework7-react';
import { getChat, type ChatDetail } from '@/api/chats';
import { getMembers, addMember, type MemberResponse } from '@/api/members';
import './group-detail.scss';

interface Props {
  f7route?: { params: Record<string, string> };
}

function groupDisplayName(detail: ChatDetail | null, id: string): string {
  if (detail?.name?.trim()) return detail.name.trim();
  return `Chat ${id}`;
}

function avatarUrl(detail: ChatDetail | null): string | null {
  if (detail?.avatar?.trim()) return detail.avatar.trim();
  return null;
}

function initials(detail: ChatDetail | null, id: string): string {
  const name = detail?.name?.trim();
  if (name && name.length > 0) return name.charAt(0).toUpperCase();
  return '?';
}

export default function GroupDetail({ f7route }: Props) {
  const id = f7route?.params?.id ?? '';
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
        f7.toast.create({ text: msg, closeTimeout: 3000 }).open();
      })
      .finally(() => setLoading(false));
  }, [id]);

  if (!id) {
    return (
      <Page>
        <Navbar title="Group" backLink />
        <Block>Invalid group.</Block>
      </Page>
    );
  }

  const avatar = avatarUrl(detail);
  const displayName = groupDisplayName(detail, id);

  const refreshMembers = () => {
    getMembers(id)
      .then((res) => setMembers(res.data ?? []))
      .catch((err: Error) => {
        f7.toast.create({ text: err?.message ?? 'Failed to refresh members', closeTimeout: 3000 }).open();
      });
  };

  const handleAddMember = () => {
    f7.dialog.prompt(
      'Enter the user ID (uid) to add as a member:',
      'Add Member',
      (value) => {
        if (value == null || value.trim() === '') return;
        const uid = parseInt(value.trim(), 10);
        if (Number.isNaN(uid) || uid < 1) {
          f7.toast.create({ text: 'Please enter a valid user ID (positive number).', closeTimeout: 3000 }).open();
          return;
        }
        addMember(id, uid)
          .then(() => {
            f7.toast.create({ text: 'Member added.', closeTimeout: 2000 }).open();
            refreshMembers();
          })
          .catch((err: Error & { response?: { status?: number } }) => {
            const msg =
              err?.response?.status === 409
                ? 'User is already a member.'
                : err?.response?.status === 404
                  ? 'User or chat not found.'
                  : err?.message ?? 'Failed to add member';
            f7.toast.create({ text: msg, closeTimeout: 3000 }).open();
          });
      }
    );
  };

  return (
    <Page>
      <Navbar title="Group" backLink />
      {loading ? (
        <Block strong inset>
          <p>Loading…</p>
        </Block>
      ) : error ? (
        <Block strong inset>
          <p>{error}</p>
        </Block>
      ) : (
        <>
          <Block strong inset>
            <BlockTitle>Group name</BlockTitle>
            <p>{displayName}</p>
          </Block>
          <Block strong inset>
            <BlockTitle>Group avatar</BlockTitle>
            <div className="group-detail-avatar">
              {avatar ? (
                <img src={avatar} alt="" className="group-detail-avatar-img" />
              ) : (
                <div className="group-detail-avatar-placeholder" aria-hidden>
                  {initials(detail, id)}
                </div>
              )}
            </div>
          </Block>
          <Block strong inset>
            <BlockTitle>Group notes</BlockTitle>
            {detail?.description?.trim() ? (
              <p>{detail.description.trim()}</p>
            ) : (
              <p className="text-color-secondary">No notes.</p>
            )}
          </Block>
          <BlockTitle>Members</BlockTitle>
          <List dividers strong>
            <ListButton title="Add Member" onClick={handleAddMember} />
            {
              members.map((m) => (
                <ListItem
                  key={m.uid}
                  title={m.username ?? `User ${m.uid}`}
                  after={m.role}
                />
              ))
            }
          </List>
        </>
      )}
    </Page>
  );
}
