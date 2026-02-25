import React, { useState, useEffect } from 'react';
import {
  f7,
  List,
  ListItem,
  Navbar,
  Link,
  Page,
  SwipeoutActions,
  SwipeoutButton,
  Icon,
} from 'framework7-react';
import '@/css/chats.scss';
import { getChats } from '@/api/chats.js';

function formatLastActivity(isoString) {
  if (!isoString) return '';
  const date = new Date(isoString);
  return Intl.DateTimeFormat('en', {
    month: 'short',
    year: 'numeric',
    day: 'numeric',
  }).format(date);
}

function chatDisplayName(chat) {
  if (chat.name && chat.name.trim()) return chat.name;
  return `Chat ${chat.id}`;
}

export default function Chats() {
  const [chats, setChats] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    let cancelled = false;
    getChats()
      .then((res) => {
        if (!cancelled) {
          setChats(res.data.chats || []);
          setError(null);
        }
      })
      .catch((err) => {
        if (!cancelled) {
          setError(err.message || 'Failed to load chats');
          setChats([]);
        }
      })
      .finally(() => {
        if (!cancelled) setLoading(false);
      });
    return () => { cancelled = true; };
  }, []);

  const swipeoutUnread = () => f7.dialog.alert('Unread');
  const swipeoutPin = () => f7.dialog.alert('Pin');
  const swipeoutMore = () => f7.dialog.alert('More');
  const swipeoutArchive = () => f7.dialog.alert('Archive');

  return (
    <Page className="chats-page">
      <Navbar title="Chats" large transparent>
        <Link slot="left">Edit</Link>
        <Link slot="right" iconF7="square_pencil" href="#" onClick={() => f7.dialog.alert('New Chat – coming soon')} />
      </Navbar>
      {error && (
        <List>
          <ListItem title="Error" after={error} />
        </List>
      )}
      {loading && !error && (
        <List>
          <ListItem title="Loading…" />
        </List>
      )}
      {!loading && !error && (
        <List noChevron dividers mediaList className="chats-list">
          {chats.length === 0 && (
            <ListItem title="No chats yet" />
          )}
          {chats.map((chat) => (
            <ListItem
              key={chat.id}
              link={`/chats/${chat.id}/`}
              title={chatDisplayName(chat)}
              after={formatLastActivity(chat.last_message_at)}
              swipeout
            >
              <div slot="media" className="chats-list-avatar">
                {chat.name && chat.name.trim() ? chat.name.trim().charAt(0).toUpperCase() : '?'}
              </div>
              <span slot="text">Last activity</span>
              <SwipeoutActions left>
                <SwipeoutButton close overswipe color="blue" onClick={swipeoutUnread}>
                  <Icon f7="chat_bubble_fill" />
                  <span>Unread</span>
                </SwipeoutButton>
                <SwipeoutButton close color="gray" onClick={swipeoutPin}>
                  <Icon f7="pin_fill" />
                  <span>Pin</span>
                </SwipeoutButton>
              </SwipeoutActions>
              <SwipeoutActions right>
                <SwipeoutButton close color="gray" onClick={swipeoutMore}>
                  <Icon f7="ellipsis" />
                  <span>More</span>
                </SwipeoutButton>
                <SwipeoutButton close overswipe color="light-blue" onClick={swipeoutArchive}>
                  <Icon f7="archivebox_fill" />
                  <span>Archive</span>
                </SwipeoutButton>
              </SwipeoutActions>
            </ListItem>
          ))}
        </List>
      )}
    </Page>
  );
}
