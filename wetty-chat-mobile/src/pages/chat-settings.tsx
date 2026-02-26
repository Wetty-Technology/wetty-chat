import React, { useState, useEffect } from 'react';
import {
  f7,
  Page,
  Navbar,
  List,
  ListInput,
  ListItem,
  Block,
  Button,
} from 'framework7-react';
import { getChatDetails, updateChat } from '@/api/chats';

interface Props {
  f7route?: {
    params: Record<string, string>;
  };
}

export default function ChatSettingsPage({ f7route }: Props) {
  const { id } = f7route?.params || {};
  const chatId = id ? String(id) : '';

  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [avatar, setAvatar] = useState('');
  const [visibility, setVisibility] = useState<'public' | 'private'>('public');
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (!chatId) return;
    setLoading(true);
    getChatDetails(chatId)
      .then((res) => {
        setName(res.data.name || '');
        setDescription(res.data.description || '');
        setAvatar(res.data.avatar || '');
        setVisibility(res.data.visibility as 'public' | 'private');
      })
      .catch((err: Error) => {
        f7.toast.create({ text: err.message || 'Failed to load chat details', closeTimeout: 3000 }).open();
      })
      .finally(() => setLoading(false));
  }, [chatId]);

  const handleSave = () => {
    if (!chatId) return;
    setSaving(true);
    updateChat(chatId, {
      name: name.trim() || undefined,
      description: description.trim() || undefined,
      avatar: avatar.trim() || undefined,
      visibility,
    })
      .then(() => {
        f7.toast.create({ text: 'Settings saved', closeTimeout: 2000 }).open();
        f7.views.main.router.back();
      })
      .catch((err: Error) => {
        f7.toast.create({ text: err.message || 'Failed to save settings', closeTimeout: 3000 }).open();
      })
      .finally(() => setSaving(false));
  };

  return (
    <Page>
      <Navbar title="Group Settings" backLink />
      {loading ? (
        <Block>Loading...</Block>
      ) : (
        <>
          <List>
            <ListInput
              label="Group Name"
              type="text"
              placeholder="Enter group name"
              value={name}
              onInput={(e) => setName((e.target as HTMLInputElement).value)}
            />
            <ListInput
              label="Description"
              type="textarea"
              placeholder="Enter group description"
              value={description}
              onInput={(e) => setDescription((e.target as HTMLTextAreaElement).value)}
            />
            <ListInput
              label="Avatar URL"
              type="url"
              placeholder="Enter avatar URL"
              value={avatar}
              onInput={(e) => setAvatar((e.target as HTMLInputElement).value)}
            />
            <ListItem
              title="Visibility"
              smartSelect
              smartSelectParams={{ openIn: 'popover' }}
            >
              <select
                name="visibility"
                value={visibility}
                onChange={(e) => setVisibility(e.target.value as 'public' | 'private')}
              >
                <option value="public">Public</option>
                <option value="private">Private</option>
              </select>
            </ListItem>
          </List>
          <Block>
            <Button fill large disabled={saving} onClick={handleSave}>
              {saving ? 'Saving...' : 'Save Settings'}
            </Button>
          </Block>
        </>
      )}
    </Page>
  );
}
