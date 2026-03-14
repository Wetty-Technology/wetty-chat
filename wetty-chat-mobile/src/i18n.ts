import { i18n } from "@lingui/core";
import { detectLocale, supportedLocales } from "./store/settingsSlice";

export async function dynamicActivate(locale: string) {
  const { messages } = await import(`../locales/${locale}/messages.po`);
  i18n.load(locale, messages);
  i18n.activate(locale);
  document.documentElement.lang = locale;
}

export async function activateDetectedLocale() {
  let locale: string | undefined;
  try {
    const raw = localStorage.getItem('settings');
    if (raw) {
      const saved = JSON.parse(raw).locale;
      if (saved && supportedLocales.includes(saved)) {
        locale = saved;
      }
    }
  } catch {
    // ignore
  }
  await dynamicActivate(locale ?? detectLocale());
}

export { i18n };
