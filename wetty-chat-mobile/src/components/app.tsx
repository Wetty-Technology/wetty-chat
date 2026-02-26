import React, { useState } from 'react';
import { useSelector } from 'react-redux';

import {
  f7,
  f7ready,
  App,
  Panel,
  Views,
  View,
  Popup,
  Page,
  Navbar,
  Toolbar,
  ToolbarPane,
  NavRight,
  Link,
  Block,
  BlockTitle,
  LoginScreen,
  LoginScreenTitle,
  List,
  ListItem,
  ListInput,
  ListButton,
  BlockFooter
} from 'framework7-react';


import { initWebSocket } from '@/api/ws';
import routes from '@/js/routes';
import type { RootState } from '@/store/index';
import './app.scss';

const MyApp = () => {
  // Login screen demo data
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const wsConnected = useSelector((state: RootState) => state.connection.wsConnected);

  // Framework7 Parameters (store omitted; using Redux)
  const f7params = {
    name: 'wetty-chat-mobile', // App name
      theme: 'auto', // Automatic theme detection
      // App routes
      routes: routes,
  };
  const alertLoginData = () => {
    f7.dialog.alert('Username: ' + username + '<br>Password: ' + password, () => {
      f7.loginScreen.close();
    });
  }
  f7ready(() => {
    initWebSocket();
    // Call F7 APIs here
  });

  return (
    <App { ...f7params }>
        {!wsConnected && (
          <div className="ws-disconnected-banner">
            Disconnected. Retrying…
          </div>
        )}
        <Views tabs className="safe-areas">
          <Toolbar tabbar icons bottom>
            <ToolbarPane>
              <Link tabLink="#view-chats" tabLinkActive iconIos="f7:chat_bubble_2_fill" iconMd="material:message" text="Chats" />
              <Link tabLink="#view-settings" iconIos="f7:gear" iconMd="material:settings" text="Settings" />
            </ToolbarPane>
          </Toolbar>

          {/* Your main view/tab, should have "view-main" class. It also has "tabActive" prop */}
          <View id="view-chats" main tab tabActive url="/chats/" />
          <View id="view-settings" tab url="/settings/" />

        </Views>

      {/* Popup */}
      <Popup id="my-popup">
        <View>
          <Page>
            <Navbar title="Popup">
              <NavRight>
                <Link popupClose>Close</Link>
              </NavRight>
            </Navbar>
            <Block>
              <p>Popup content goes here.</p>
            </Block>
          </Page>
        </View>
      </Popup>

      <LoginScreen id="my-login-screen">
        <View>
          <Page loginScreen>
            <LoginScreenTitle>Login</LoginScreenTitle>
            <List form>
              <ListInput
                type="text"
                name="username"
                placeholder="Your username"
                value={username}
                onInput={(e) => setUsername((e.target as HTMLInputElement).value)}
              ></ListInput>
              <ListInput
                type="password"
                name="password"
                placeholder="Your password"
                value={password}
                onInput={(e) => setPassword((e.target as HTMLInputElement).value)}
              ></ListInput>
            </List>
            <List>
              <ListButton title="Sign In" onClick={() => alertLoginData()} />
              <BlockFooter>
                Some text about login information.<br />Click "Sign In" to close Login Screen
              </BlockFooter>
            </List>
          </Page>
        </View>
      </LoginScreen>
    </App>
  )
}
export default MyApp;
