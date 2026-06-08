import { useSelector } from 'react-redux';
import type { RootState } from '@/store';

export function hasGlobalPermission(
  permissions: string[],
  permission: string | string[],
): boolean {
  const allowedPermissions = Array.isArray(permission) ? permission : [permission];
  if (permissions.includes('permission.all')) {
    return true;
  }
  return allowedPermissions.some((allowedPermission) => permissions.includes(allowedPermission));
}

export function useHasGlobalPermission(permission: string | string[]): boolean {
  const permissions = useSelector((state: RootState) => state.user.permissions);
  return hasGlobalPermission(permissions, permission);
}
