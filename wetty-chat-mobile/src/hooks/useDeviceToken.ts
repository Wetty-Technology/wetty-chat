import { useMemo } from 'react';
import { getJwtTokenFromQuery, getStoredJwtToken } from '@/utils/jwtToken';

export function useDeviceToken(allowQuery: boolean = false): string {
  if (allowQuery) {
    const queryToken = getJwtTokenFromQuery(document.location.search);
    if (queryToken) {
      return queryToken;
    }
  }
  return useMemo(() => getStoredJwtToken(), []);
}
