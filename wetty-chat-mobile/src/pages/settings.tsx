import React, { useState, useEffect } from 'react';
import { f7, Page, Navbar, List, ListInput, ListButton, Block, BlockTitle } from 'framework7-react';
import { getCurrentUserId, setCurrentUserId } from '@/js/current-user';
import styles from './settings.module.scss';

export default function Settings() {
  const [uidInput, setUidInput] = useState(String(getCurrentUserId()));

  useEffect(() => {
    setUidInput(String(getCurrentUserId()));
  }, []);

  const handleSave = () => {
    const trimmed = uidInput.trim();
    const n = parseInt(trimmed, 10);
    if (!Number.isFinite(n) || n < 1) {
      f7.toast.create({ text: 'Enter a valid User ID (integer ≥ 1)' }).open();
      return;
    }
    setCurrentUserId(n);
    window.location.reload();
  };

  return (
    <Page>
      <Navbar title="Settings" />
      <Block strong inset>
        <BlockTitle>Account</BlockTitle>
        <List form>
          <ListInput
            className={styles['uid-input']}
            type="number"
            label="User ID"
            placeholder="e.g. 1"
            value={uidInput}
            inputId="uid-input"
            onInput={(e) => setUidInput((e.target as HTMLInputElement).value)}
          />
          <ListButton title="Save" onClick={handleSave} />
        </List>
      </Block>
    </Page>
  );
}
