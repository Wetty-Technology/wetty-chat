import { t } from '@lingui/core/macro';
import type { InviteInfoResponse } from '@/api/invites';
import { buildInviteUrl } from '@/utils/inviteUrl';

export type InviteMode = 'public' | 'membership' | 'targeted';
export type ModalStep = 'configure' | 'destination';
export type InviteExpiryOption = 'never' | '1d' | '7d' | '30d';
export type SelectorTarget = 'required' | 'destination';

export function getExpiryOptions(): Array<{ value: InviteExpiryOption; label: string }> {
  return [
    { value: 'never', label: t`Never` },
    { value: '1d', label: t`24 hours` },
    { value: '7d', label: t`7 days` },
    { value: '30d', label: t`30 days` },
  ];
}

export function getExpiresAt(expiryOption: InviteExpiryOption): string | null {
  if (expiryOption === 'never') {
    return null;
  }

  const now = Date.now();
  const durations: Record<Exclude<InviteExpiryOption, 'never'>, number> = {
    '1d': 24 * 60 * 60 * 1000,
    '7d': 7 * 24 * 60 * 60 * 1000,
    '30d': 30 * 24 * 60 * 60 * 1000,
  };

  return new Date(now + durations[expiryOption]).toISOString();
}

export function getInviteDescription(mode: InviteMode): string {
  if (mode === 'membership') {
    return t`Only members of a selected group can use this invite link to join.`;
  }

  if (mode === 'targeted') {
    return t`Only the selected user can redeem this invite link to join.`;
  }

  return t`Anyone with this invite link can use it until it expires or is revoked.`;
}

export function getExpiryLabel(expiryOption: InviteExpiryOption): string {
  return getExpiryOptions().find((option) => option.value === expiryOption)?.label ?? t`Never`;
}

export function canCopyInviteCode(): boolean {
  return typeof navigator !== 'undefined' && typeof navigator.clipboard?.writeText === 'function';
}

export async function copyInviteCode(invite: InviteInfoResponse): Promise<void> {
  await navigator.clipboard.writeText(buildInviteUrl(invite.code));
}
