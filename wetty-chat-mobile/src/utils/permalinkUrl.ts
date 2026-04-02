const PERMALINK_PATH_PREFIX = '/m/';

/**
 * Pack two snowflake ID strings into a base64url-encoded segment.
 * Each ID is treated as a BigInt and written as an 8-byte big-endian value,
 * giving 16 bytes total → 22 base64url characters (no padding).
 */
export function encodePermalink(chatId: string, messageId: string): string {
  const buf = new ArrayBuffer(16);
  const view = new DataView(buf);
  view.setBigUint64(0, BigInt(chatId));
  view.setBigUint64(8, BigInt(messageId));

  let binary = '';
  const bytes = new Uint8Array(buf);
  for (const b of bytes) {
    binary += String.fromCharCode(b);
  }

  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

export function decodePermalink(encoded: string): { chatId: string; messageId: string } {
  // Restore standard base64
  let b64 = encoded.replace(/-/g, '+').replace(/_/g, '/');
  while (b64.length % 4 !== 0) b64 += '=';

  const binary = atob(b64);
  const buf = new ArrayBuffer(16);
  const bytes = new Uint8Array(buf);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }

  const view = new DataView(buf);
  const chatId = view.getBigUint64(0).toString();
  const messageId = view.getBigUint64(8).toString();

  return { chatId, messageId };
}

export function buildPermalinkUrl(chatId: string, messageId: string): string {
  return document.location.origin + PERMALINK_PATH_PREFIX + encodePermalink(chatId, messageId);
}

export function parsePermalinkSegment(pathname: string): string | null {
  if (!pathname.startsWith(PERMALINK_PATH_PREFIX)) return null;
  const segment = pathname.slice(PERMALINK_PATH_PREFIX.length);
  if (!segment) return null;
  return segment;
}
