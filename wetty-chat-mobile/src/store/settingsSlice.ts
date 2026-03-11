import { createSlice } from '@reduxjs/toolkit';
import type { PayloadAction } from '@reduxjs/toolkit';
import type { RootState } from './index';

export const supportedLocales = ["en", "zh-CN", "zh-TW"];
export const defaultLocale = "en";

export function detectLocale(): string {
  for (const lang of navigator.languages) {
    // Exact match (e.g. "zh-CN")
    if (supportedLocales.includes(lang)) return lang;
    // Base language match (e.g. "zh" -> "zh-CN")
    const base = lang.split("-")[0];
    const match = supportedLocales.find((l) => l.split("-")[0] === base);
    if (match) return match;
  }
  return defaultLocale;
}

export interface SettingsState {
  locale: string | null;
}

function loadInitialState(): SettingsState {
  try {
    const raw = localStorage.getItem('settings');
    if (raw) {
      const parsed = JSON.parse(raw);
      return { locale: parsed.locale ?? null };
    }
  } catch {
    // ignore corrupt data
  }
  return { locale: null };
}

const settingsSlice = createSlice({
  name: 'settings',
  initialState: loadInitialState(),
  reducers: {
    setLocale(state, action: PayloadAction<string | null>) {
      state.locale = action.payload;
      localStorage.setItem('settings', JSON.stringify({ locale: action.payload }));
    },
  },
});

export const { setLocale } = settingsSlice.actions;
export const selectLocale = (state: RootState) => state.settings.locale;
export const selectEffectiveLocale = (state: RootState) => state.settings.locale ?? detectLocale();
export default settingsSlice.reducer;
