import { i18n } from "@lingui/core";

const supportedLocales = ["en", "zh-CN"];
const defaultLocale = "en";

function detectLocale(): string {
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

export async function dynamicActivate(locale: string) {
  const { messages } = await import(`../locales/${locale}/messages.ts`);
  i18n.load(locale, messages);
  i18n.activate(locale);
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
