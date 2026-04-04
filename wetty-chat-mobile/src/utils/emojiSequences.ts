import emojiRegex from 'emoji-regex-xs';

const nativeEmojiRegex = (() => {
  try {
    return {
      exact: new RegExp('^\\p{RGI_Emoji}$', 'v'),
      global: new RegExp('\\p{RGI_Emoji}', 'gv'),
    };
  } catch {
    return null;
  }
})();

const fallbackEmojiRegex = (() => {
  const regex = emojiRegex();
  const flags = regex.flags.replace('g', '');

  return {
    exact: new RegExp(`^(?:${regex.source})$`, flags),
    global: regex,
  };
})();

function getEmojiRegex() {
  return nativeEmojiRegex ?? fallbackEmojiRegex;
}

export function isEmojiSequence(value: string): boolean {
  if (!value) {
    return false;
  }

  return getEmojiRegex().exact.test(value);
}

export function extractEmojiSequences(value: string): string[] {
  if (!value) {
    return [];
  }

  return Array.from(value.matchAll(getEmojiRegex().global), (match) => match[0]);
}
