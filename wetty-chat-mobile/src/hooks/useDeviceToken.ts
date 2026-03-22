import { useMemo } from 'react';
import { getStoredJwtToken } from '@/utils/jwtToken';

export function useDeviceToken(): string {
    return useMemo(() => getStoredJwtToken(), []);
}
