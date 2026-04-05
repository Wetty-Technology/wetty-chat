import type { PayloadAction } from '@reduxjs/toolkit';
import { createSlice, createAsyncThunk, current } from '@reduxjs/toolkit';
import type { RootState } from './index';
import { kvSet } from '@/utils/db';

export const supportedLocales = ['en', 'zh-CN', 'zh-TW'];
export const defaultLocale = 'en';
export const chatFontSizeOptions = ['small', 'mediumSmall', 'medium', 'mediumLarge', 'large'] as const;
export type ChatFontSizeOption = (typeof chatFontSizeOptions)[number];
export const defaultChatFontSize: ChatFontSizeOption = 'medium';

const chatFontSizeStyles: Record<ChatFontSizeOption, string> = {
  small: '12px',
  mediumSmall: '14px',
  medium: 'inherit',
  mediumLarge: '18px',
  large: '20px',
};

export function detectLocale(): string {
  for (const lang of navigator.languages) {
    if (supportedLocales.includes(lang)) return lang;
    const base = lang.split('-')[0];
    const match = supportedLocales.find((l) => l.split('-')[0] === base);
    if (match) return match;
  }
  return defaultLocale;
}

export interface SettingsState {
  locale: string | null;
  messageFontSize: ChatFontSizeOption;
  showAllTab: boolean;
  autoSortStickerPacks: boolean;
  stickerPackOrder: string[];
}

export function isChatFontSizeOption(value: unknown): value is ChatFontSizeOption {
  return typeof value === 'string' && chatFontSizeOptions.includes(value as ChatFontSizeOption);
}

// Ensure remote sync does not hammer the server
let syncTimeout: ReturnType<typeof setTimeout> | null = null;

function persistSettings(state: SettingsState) {
  // Use current so we aren't passing immer's proxy objects to IDB/Axios
  const snapshot = current(state);
  void kvSet('settings', {
    locale: snapshot.locale,
    messageFontSize: snapshot.messageFontSize,
    showAllTab: snapshot.showAllTab,
    autoSortStickerPacks: snapshot.autoSortStickerPacks,
    stickerPackOrder: snapshot.stickerPackOrder,
  });

  // Debounced server sync
  if (syncTimeout) clearTimeout(syncTimeout);
  syncTimeout = setTimeout(() => {
    import('@/api/users').then(({ usersApi }) => {
      void usersApi
        .patchUserSettings({
          general: {
            showAllTab: snapshot.showAllTab,
            locale: snapshot.locale,
          },
          stickers: {
            autoSortStickerPacks: snapshot.autoSortStickerPacks,
            stickerPackOrder: snapshot.stickerPackOrder,
          },
        })
        .catch((err) => {
          console.error('Failed to sync settings to server', err);
        });
    });
  }, 1000);
}

function persistEffectiveLocale(locale: string | null) {
  const effective = locale && supportedLocales.includes(locale) ? locale : detectLocale();
  void kvSet('effective_locale', effective);
}

export function getChatFontSizeStyle(messageFontSize: ChatFontSizeOption): string {
  return chatFontSizeStyles[messageFontSize];
}

const defaultSettings: SettingsState = {
  locale: null,
  messageFontSize: defaultChatFontSize,
  showAllTab: true,
  autoSortStickerPacks: false,
  stickerPackOrder: [],
};

export function hydrateSettings(saved: any): SettingsState {
  return {
    ...defaultSettings,
    locale: saved?.general?.locale ?? saved?.locale ?? defaultSettings.locale,
    messageFontSize: isChatFontSizeOption(saved?.chat?.messageFontSize)
      ? saved.chat.messageFontSize
      : isChatFontSizeOption(saved?.messageFontSize)
        ? saved.messageFontSize
        : defaultChatFontSize,
    showAllTab: saved?.general?.showAllTab ?? saved?.showAllTab ?? defaultSettings.showAllTab,
    autoSortStickerPacks:
      saved?.stickers?.autoSortStickerPacks ?? saved?.autoSortStickerPacks ?? defaultSettings.autoSortStickerPacks,
    stickerPackOrder: Array.isArray(saved?.stickers?.stickerPackOrder)
      ? saved.stickers.stickerPackOrder
      : Array.isArray(saved?.stickerPackOrder)
        ? saved.stickerPackOrder
        : defaultSettings.stickerPackOrder,
  };
}

export const fetchRemoteSettings = createAsyncThunk('settings/fetchRemoteSettings', async (_, { dispatch }) => {
  const { usersApi } = await import('@/api/users');
  try {
    const prefs = await usersApi.getUserSettings();
    const flatPrefs = hydrateSettings(prefs);
    dispatch(replaceSettings(flatPrefs));
  } catch (err) {
    console.error('Failed to fetch user settings', err);
  }
});

const settingsSlice = createSlice({
  name: 'settings',
  initialState: defaultSettings,
  reducers: {
    setLocale(state, action: PayloadAction<string | null>) {
      state.locale = action.payload;
      persistSettings(state);
      persistEffectiveLocale(state.locale);
    },
    setMessageFontSize(state, action: PayloadAction<ChatFontSizeOption>) {
      state.messageFontSize = action.payload;
      persistSettings(state);
    },
    setShowAllTab(state, action: PayloadAction<boolean>) {
      state.showAllTab = action.payload;
      persistSettings(state);
    },
    setAutoSortStickerPacks(state, action: PayloadAction<boolean>) {
      state.autoSortStickerPacks = action.payload;
      persistSettings(state);
    },
    setStickerPackOrder(state, action: PayloadAction<string[]>) {
      state.stickerPackOrder = action.payload;
      persistSettings(state);
    },
    replaceSettings(state, action: PayloadAction<Partial<SettingsState>>) {
      if (action.payload.locale !== undefined) state.locale = action.payload.locale;
      if (action.payload.showAllTab !== undefined) state.showAllTab = action.payload.showAllTab;
      if (action.payload.autoSortStickerPacks !== undefined)
        state.autoSortStickerPacks = action.payload.autoSortStickerPacks;
      if (Array.isArray(action.payload.stickerPackOrder)) state.stickerPackOrder = action.payload.stickerPackOrder;

      // Store in IndexedDB but do NOT sync back to server (since it just came from server)
      const snapshot = current(state);
      void kvSet('settings', {
        locale: snapshot.locale,
        messageFontSize: snapshot.messageFontSize,
        showAllTab: snapshot.showAllTab,
        autoSortStickerPacks: snapshot.autoSortStickerPacks,
        stickerPackOrder: snapshot.stickerPackOrder,
      });
      if (action.payload.locale !== undefined) {
        persistEffectiveLocale(snapshot.locale);
      }
    },
  },
});

export const {
  setLocale,
  setMessageFontSize,
  setShowAllTab,
  setAutoSortStickerPacks,
  setStickerPackOrder,
  replaceSettings,
} = settingsSlice.actions;
export const selectLocale = (state: RootState) => state.settings.locale;
export const selectEffectiveLocale = (state: RootState) => state.settings.locale ?? detectLocale();
export const selectMessageFontSize = (state: RootState) => state.settings.messageFontSize;
export const selectShowAllTab = (state: RootState) => state.settings.showAllTab;
export const selectAutoSortStickerPacks = (state: RootState) => state.settings.autoSortStickerPacks;
export const selectStickerPackOrder = (state: RootState) => state.settings.stickerPackOrder;
export const selectChatFontSizeStyle = (state: RootState) => getChatFontSizeStyle(state.settings.messageFontSize);
export default settingsSlice.reducer;
