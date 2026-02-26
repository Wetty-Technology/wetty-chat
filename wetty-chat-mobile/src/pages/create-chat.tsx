import React, { useState } from 'react';
import { f7, Page, Navbar, List, ListInput, ListButton, Block, BlockTitle } from 'framework7-react';
import { createChat } from '@/api/chats';

export default function CreateChat() {
  const [name, setName] = useState('');
  const [submitting, setSubmitting] = useState(false);

  const handleSubmit = () => {
    const trimmed = name.trim() || undefined;
    setSubmitting(true);
    createChat({ name: trimmed })
      .then(() => {
        const view = f7.views.main;
        view?.router?.navigate('/chats/', { reloadCurrent: true });
      })
      .catch((err: { message?: string }) => {
        f7.dialog.alert(err?.message ?? 'Failed to create chat');
      })
      .finally(() => {
        setSubmitting(false);
      });
  };

  return (
    <Page>
      <Navbar title="New Chat" backLink />
      <Block strong inset>
        <BlockTitle>Chat name</BlockTitle>
        <List form>
          <ListInput
            type="text"
            placeholder="Optional"
            value={name}
            onInput={(e) => setName((e.target as HTMLInputElement).value)}
            clearButton
          />
          <ListButton
            title="Create"
            onClick={handleSubmit}
            disabled={submitting}
          />
        </List>
      </Block>
    </Page>
  );
}
