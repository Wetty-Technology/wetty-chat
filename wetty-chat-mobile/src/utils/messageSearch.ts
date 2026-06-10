export function isMessageSearchQueryReady(query: string): boolean {
  return query.trim().length >= 2;
}
