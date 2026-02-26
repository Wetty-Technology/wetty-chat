import React from 'react';
import { Page, Navbar, Block } from 'framework7-react';

interface Props {
  f7route?: { params: Record<string, string> };
}

export default function ChatThread({ f7route }: Props) {
  const { id } = f7route?.params || {};
  return (
    <Page>
      <Navbar title={`Chat ${id || '?'}`} backLink />
      <Block strong inset>
        <p>Chat thread – coming soon.</p>
        <p>Messages will load here via GET /chats/:id/messages.</p>
      </Block>
    </Page>
  );
}
