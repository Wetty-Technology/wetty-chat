import React from 'react';
import { Page, Navbar, Block } from 'framework7-react';

export default function ChatThread(props) {
  const { id } = props.f7route?.params || {};
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
