import { type Feature, isFeatureEnabled } from '@/features';
import { useSelector } from 'react-redux';
import type { RootState } from '@/store';
import { selectFeatureOverrideEntryByUid } from '@/store/featureOverridesSlice';

export function useFeatureGate(feature: Feature): boolean {
  const uid = useSelector((state: RootState) => state.user.uid);
  useSelector((state: RootState) => state.user.permissions);
  useSelector((state: RootState) => selectFeatureOverrideEntryByUid(state, uid));
  return isFeatureEnabled(feature);
}
