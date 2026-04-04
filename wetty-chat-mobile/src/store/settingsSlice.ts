import type { PayloadAction } from '@reduxjs/toolkit';
import { createSlice } from '@reduxjs/toolkit';
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
}

export function isChatFontSizeOption(value: unknown): value is ChatFontSizeOption {
  return typeof value === 'string' && chatFontSizeOptions.includes(value as ChatFontSizeOption);
}

function persistSettings(state: SettingsState) {
  void kvSet('settings', {
    locale: state.locale,
    messageFontSize: state.messageFontSize,
    showAllTab: state.showAllTab,
  });
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
};

export function hydrateSettings(saved: Partial<SettingsState> | null | undefined): SettingsState {
  return {
    ...defaultSettings,
    ...saved,
    messageFontSize: isChatFontSizeOption(saved?.messageFontSize) ? saved.messageFontSize : defaultChatFontSize,
  };
}

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
  },
});

export const { setLocale, setMessageFontSize, setShowAllTab } = settingsSlice.actions;
export const selectLocale = (state: RootState) => state.settings.locale;
export const selectEffectiveLocale = (state: RootState) => state.settings.locale ?? detectLocale();
export const selectMessageFontSize = (state: RootState) => state.settings.messageFontSize;
export const selectShowAllTab = (state: RootState) => state.settings.showAllTab;
export const selectChatFontSizeStyle = (state: RootState) => getChatFontSizeStyle(state.settings.messageFontSize);
export default settingsSlice.reducer;
