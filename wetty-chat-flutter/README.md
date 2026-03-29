# wetty-chat-flutter

Flutter client for wetty-chat.

## API base URL

The app reads the API base URL from a compile-time define:

```dart
const String apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://chahui.app/_api',
);
```

If `API_BASE_URL` is not provided, the app uses `https://chahui.app/_api`.

## Run with a development API

From the terminal:

```bash
flutter run --dart-define=API_BASE_URL=http://wchat.i386.mov/_api
```

## VS Code

Use a launch configuration that passes `--dart-define` to the Flutter tool:

```json
"toolArgs": [
  "--dart-define",
  "API_BASE_URL=http://your-local-api:3000"
]
```

Do a full restart after changing it. Hot reload does not change compile-time defines.

The app prints the active API URL once at startup so you can confirm the define was applied:

```text
[APP] API_BASE_URL=...
```
