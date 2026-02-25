# wetty-chat-mobile

## Framework7 CLI Options

Framework7 app created with following options:

```
{
  "cwd": "/home/codetector/dev/wetty-chat",
  "type": [
    "web"
  ],
  "name": "wetty-chat-mobile",
  "framework": "react",
  "template": "tabs",
  "cssPreProcessor": "scss",
  "bundler": "vite",
  "theming": {
    "customColor": false,
    "color": "#007aff",
    "darkMode": false,
    "iconFonts": true
  },
  "customBuild": false
}
```

## Install Dependencies

First of all we need to install dependencies, run in terminal
```
npm install
```

## NPM Scripts

* 🔥 `start` - run development server
* 🔧 `dev` - run development server
* 🔧 `build` - build web app for production

## API and backend

* **Development**: The dev server proxies `/api` to the backend at `http://localhost:3000`. Start the backend (e.g. `cargo run` in `backend/`) so the chat list can load. No `.env` is required for dev.
* **Production**: Set `VITE_API_BASE_URL` to your backend URL when building (e.g. in CI or `.env.production`). Copy `.env.example` to `.env` and fill in if needed.
* **Auth**: The backend expects an `X-User-Id` header (integer). The app currently sends a placeholder; replace this with real auth (e.g. login → store user id → set header in `src/api/client.js`) when you implement it.

## Vite

There is a [Vite](https://vitejs.dev) bundler setup. It compiles and bundles all "front-end" resources. You should work only with files located in `/src` folder. Vite config located in `vite.config.js`.
## Assets

Assets (icons, splash screens) source images located in `assets-src` folder. To generate your own icons and splash screen images, you will need to replace all assets in this directory with your own images (pay attention to image size and format), and run the following command in the project directory:

```
framework7 assets
```

Or launch UI where you will be able to change icons and splash screens:

```
framework7 assets --ui
```



## Documentation & Resources

* [Framework7 Core Documentation](https://framework7.io/docs/)

* [Framework7 React Documentation](https://framework7.io/react/)

* [Framework7 Icons Reference](https://framework7.io/icons/)
* [Community Forum](https://forum.framework7.io)

## Support Framework7

Love Framework7? Support project by donating or pledging on:
- Patreon: https://patreon.com/framework7
- OpenCollective: https://opencollective.com/framework7