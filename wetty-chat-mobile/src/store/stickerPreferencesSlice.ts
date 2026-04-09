import type { PayloadAction } from '@reduxjs/toolkit';
import { createAsyncThunk, createSlice } from '@reduxjs/toolkit';
import type { RootState } from './index';
import { fetchCurrentUser } from './userSlice';
import { usersApi, type StickerPackOrderItem, type UpdateStickerPackOrderItem } from '@/api/users';

export interface StickerPreferencesState {
  packOrder: StickerPackOrderItem[];
  autoSortEnabled: boolean;
  hydrationStatus: 'idle' | 'kv' | 'server';
}

export interface HydratedStickerPreferences {
  state: StickerPreferencesState;
  persistPackOrder: boolean;
  clearPackOrder: boolean;
  persistAutoSort: boolean;
  clearAutoSort: boolean;
}

const initialState: StickerPreferencesState = {
  packOrder: [],
  autoSortEnabled: false,
  hydrationStatus: 'idle',
};

function normalizeOrderItems(items: StickerPackOrderItem[]): {
  packOrder: StickerPackOrderItem[];
  changed: boolean;
} {
  const deduped = new Map<string, StickerPackOrderItem>();
  let changed = false;

  for (const item of items) {
    const normalized = {
      stickerPackId: item.stickerPackId,
      lastUsedOn: Math.trunc(item.lastUsedOn),
    };

    if (normalized.lastUsedOn !== item.lastUsedOn || deduped.has(normalized.stickerPackId)) {
      changed = true;
    }

    deduped.set(normalized.stickerPackId, normalized);
  }

  return { packOrder: Array.from(deduped.values()), changed };
}

function isStickerPackOrderItem(value: unknown): value is StickerPackOrderItem {
  if (value == null || typeof value !== 'object') {
    return false;
  }

  const candidate = value as Record<string, unknown>;
  return (
    typeof candidate.stickerPackId === 'string' &&
    candidate.stickerPackId.length > 0 &&
    typeof candidate.lastUsedOn === 'number' &&
    Number.isFinite(candidate.lastUsedOn)
  );
}

function normalizePackOrderValue(savedOrder: unknown): {
  packOrder: StickerPackOrderItem[];
  persist: boolean;
  clear: boolean;
} {
  if (savedOrder == null) {
    return { packOrder: [], persist: false, clear: false };
  }

  if (!Array.isArray(savedOrder)) {
    return { packOrder: [], persist: false, clear: true };
  }

  if (savedOrder.length === 0) {
    return { packOrder: [], persist: false, clear: false };
  }

  if (savedOrder.every((item) => typeof item === 'string')) {
    const deduped = Array.from(new Set(savedOrder));
    return {
      packOrder: deduped.map((stickerPackId) => ({ stickerPackId, lastUsedOn: 0 })),
      persist: true,
      clear: false,
    };
  }

  if (!savedOrder.every(isStickerPackOrderItem)) {
    return { packOrder: [], persist: false, clear: true };
  }

  const normalized = normalizeOrderItems(savedOrder);
  return {
    packOrder: normalized.packOrder,
    persist: normalized.changed,
    clear: false,
  };
}

function normalizeAutoSortValue(savedAutoSort: unknown): {
  autoSortEnabled: boolean;
  persist: boolean;
  clear: boolean;
} {
  if (savedAutoSort == null) {
    return { autoSortEnabled: false, persist: false, clear: false };
  }

  if (typeof savedAutoSort !== 'boolean') {
    return { autoSortEnabled: false, persist: false, clear: true };
  }

  return { autoSortEnabled: savedAutoSort, persist: false, clear: false };
}

function replacePackOrder(state: StickerPreferencesState, packOrder: StickerPackOrderItem[]) {
  state.packOrder = normalizeOrderItems(packOrder).packOrder;
}

export function hydrateStickerPreferences(savedOrder: unknown, savedAutoSort: unknown): HydratedStickerPreferences {
  const normalizedOrder = normalizePackOrderValue(savedOrder);
  const normalizedAutoSort = normalizeAutoSortValue(savedAutoSort);

  return {
    state: {
      packOrder: normalizedOrder.packOrder,
      autoSortEnabled: normalizedAutoSort.autoSortEnabled,
      hydrationStatus: 'kv',
    },
    persistPackOrder: normalizedOrder.persist,
    clearPackOrder: normalizedOrder.clear,
    persistAutoSort: normalizedAutoSort.persist,
    clearAutoSort: normalizedAutoSort.clear,
  };
}

export function sortStickerPacksByPreference<T extends { id: string }>(
  packs: T[],
  packOrder: StickerPackOrderItem[],
): T[] {
  const originalIndex = new Map(packs.map((pack, index) => [pack.id, index]));
  const lastUsedByPackId = new Map(packOrder.map((item) => [item.stickerPackId, item.lastUsedOn]));

  return [...packs].sort((a, b) => {
    const lastUsedA = lastUsedByPackId.get(a.id);
    const lastUsedB = lastUsedByPackId.get(b.id);

    if (lastUsedA != null && lastUsedB != null && lastUsedA !== lastUsedB) {
      return lastUsedB - lastUsedA;
    }

    if (lastUsedA != null) {
      return -1;
    }

    if (lastUsedB != null) {
      return 1;
    }

    return (originalIndex.get(a.id) ?? 0) - (originalIndex.get(b.id) ?? 0);
  });
}

export const syncStickerPackOrder = createAsyncThunk<void, UpdateStickerPackOrderItem[], { rejectValue: string }>(
  'stickerPreferences/syncStickerPackOrder',
  async (order, { dispatch, rejectWithValue }) => {
    try {
      await usersApi.updateStickerPackOrder(order);
    } catch (err: any) {
      dispatch(fetchCurrentUser());
      return rejectWithValue(err.response?.data || err.message || 'Failed to sync sticker pack order');
    }
  },
);

const stickerPreferencesSlice = createSlice({
  name: 'stickerPreferences',
  initialState,
  reducers: {
    hydrateStickerPreferencesFromKv(
      state,
      action: PayloadAction<Pick<StickerPreferencesState, 'packOrder' | 'autoSortEnabled'>>,
    ) {
      replacePackOrder(state, action.payload.packOrder);
      state.autoSortEnabled = action.payload.autoSortEnabled;
      state.hydrationStatus = 'kv';
    },
    setAutoSortEnabled(state, action: PayloadAction<boolean>) {
      state.autoSortEnabled = action.payload;
    },
    upsertStickerPackOrderItem(state, action: PayloadAction<StickerPackOrderItem>) {
      const existing = state.packOrder.find((item) => item.stickerPackId === action.payload.stickerPackId);
      if (existing) {
        existing.lastUsedOn = Math.trunc(action.payload.lastUsedOn);
      } else {
        state.packOrder.push({
          stickerPackId: action.payload.stickerPackId,
          lastUsedOn: Math.trunc(action.payload.lastUsedOn),
        });
      }
      replacePackOrder(state, state.packOrder);
    },
    removeStickerPackOrderItem(state, action: PayloadAction<string>) {
      state.packOrder = state.packOrder.filter((item) => item.stickerPackId !== action.payload);
    },
    replaceStickerPackOrderFromWs(state, action: PayloadAction<StickerPackOrderItem[]>) {
      replacePackOrder(state, action.payload);
    },
  },
  extraReducers: (builder) => {
    builder.addCase(fetchCurrentUser.fulfilled, (state, action) => {
      replacePackOrder(state, action.payload.stickerPackOrder ?? []);
      state.hydrationStatus = 'server';
    });
  },
});

export const {
  hydrateStickerPreferencesFromKv,
  removeStickerPackOrderItem,
  replaceStickerPackOrderFromWs,
  setAutoSortEnabled,
  upsertStickerPackOrderItem,
} = stickerPreferencesSlice.actions;

export const selectStickerPreferences = (state: RootState) => state.stickerPreferences;
export const selectStickerPackOrder = (state: RootState) => state.stickerPreferences.packOrder;
export const selectStickerAutoSortEnabled = (state: RootState) => state.stickerPreferences.autoSortEnabled;
export const selectStickerHydrationStatus = (state: RootState) => state.stickerPreferences.hydrationStatus;
export const selectStickerPackOrderRankMap = (state: RootState) => {
  const sortedOrder = [...state.stickerPreferences.packOrder].sort((a, b) => b.lastUsedOn - a.lastUsedOn);
  return new Map(sortedOrder.map((item, index) => [item.stickerPackId, index]));
};

export default stickerPreferencesSlice.reducer;
