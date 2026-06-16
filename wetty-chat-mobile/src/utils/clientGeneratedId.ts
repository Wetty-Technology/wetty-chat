/**
 * Create a short-lived client-side ID (e.g. for optimistic messages).
 * Format: `{prefix}{timestamp}_{random}`, uniqueness via timestamp + random suffix.
 */
export function createClientGeneratedId(prefix: string): string {
  return `${prefix}${Date.now()}_${Math.random().toString(36).slice(2)}`;
}
