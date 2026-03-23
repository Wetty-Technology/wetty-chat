import type { PayloadAction } from '@reduxjs/toolkit';
import { createSlice } from '@reduxjs/toolkit';
import type { RootState } from './index';

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
    // Exact match (e.g. "zh-CN")
    if (supportedLocales.includes(lang)) return lang;
    // Base language match (e.g. "zh" -> "zh-CN")
    const base = lang.split('-')[0];
    const match = supportedLocales.find((l) => l.split('-')[0] === base);
    if (match) return match;
  }
  return defaultLocale;
}

export interface SettingsState {
  locale: string | null;
  messageFontSize: ChatFontSizeOption;
}

function isChatFontSizeOption(value: unknown): value is ChatFontSizeOption {
  return typeof value === 'string' && chatFontSizeOptions.includes(value as ChatFontSizeOption);
}

function loadInitialState(): SettingsState {
  try {
    const raw = localStorage.getItem('settings');
    if (raw) {
      const parsed = JSON.parse(raw);
      return {
        locale: parsed.locale ?? null,
        messageFontSize: isChatFontSizeOption(parsed.messageFontSize) ? parsed.messageFontSize : defaultChatFontSize,
      };
    }
  } catch {
    // ignore corrupt data
  }
  return { locale: null, messageFontSize: defaultChatFontSize };
}

function persistSettings(state: SettingsState) {
  localStorage.setItem('settings', JSON.stringify(state));
}

export function getChatFontSizeStyle(messageFontSize: ChatFontSizeOption): string {
  return chatFontSizeStyles[messageFontSize];
}

const settingsSlice = createSlice({
  name: 'settings',
  initialState: loadInitialState(),
  reducers: {
    setLocale(state, action: PayloadAction<string | null>) {
      state.locale = action.payload;
      persistSettings({ locale: state.locale, messageFontSize: state.messageFontSize });
    },
    setMessageFontSize(state, action: PayloadAction<ChatFontSizeOption>) {
      state.messageFontSize = action.payload;
      persistSettings({ locale: state.locale, messageFontSize: state.messageFontSize });
    },
  },
});

export const { setLocale, setMessageFontSize } = settingsSlice.actions;
export const selectLocale = (state: RootState) => state.settings.locale;
export const selectEffectiveLocale = (state: RootState) => state.settings.locale ?? detectLocale();
export const selectMessageFontSize = (state: RootState) => state.settings.messageFontSize;
export const selectChatFontSizeStyle = (state: RootState) => getChatFontSizeStyle(state.settings.messageFontSize);
export default settingsSlice.reducer;
