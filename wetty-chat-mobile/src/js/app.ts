// Import React and ReactDOM
import React from 'react';
import { createRoot } from 'react-dom/client';
import { Provider } from 'react-redux';

// Import Framework7
import Framework7 from 'framework7/lite-bundle';

// Import Framework7-React Plugin
import Framework7React from 'framework7-react';

// Import Framework7 Styles
import 'framework7/css/bundle';

// Import Icons and App Custom Styles
import '../fonts/icons.css';

// Import App Component and Redux store
import App from '../components/app';
import store from '../store/index';

// Init F7 React Plugin
Framework7.use(Framework7React);

// Mount React App
const root = createRoot(document.getElementById('app')!);
root.render(
  React.createElement(
    Provider,
    { store, children: React.createElement(App) }
  )
);
