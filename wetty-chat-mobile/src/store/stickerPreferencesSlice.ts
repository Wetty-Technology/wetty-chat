import type { PayloadAction } from '@reduxjs/toolkit';
import { createAsyncThunk, createSlice } from '@reduxjs/toolkit';
import type { RootState } from './index';
import { fetchCurrentUser } from './userSlice';
import { usersApi, type StickerPackOrderItem, type UpdateStickerPackOrderItem } from '@/api/users';

export interface FavoriteStickerOrderItem {
  stickerId: string;
  lastUsedOn: number;
}

export interface StickerPreferencesState {
  packOrder: StickerPackOrderItem[];
  autoSortEnabled: boolean;
  favoriteStickerOrder: FavoriteStickerOrderItem[];
  autoSortFavoritesEnabled: boolean;
  hydrationStatus: 'idle' | 'kv' | 'server';
}

export interface HydratedStickerPreferences {
  state: StickerPreferencesState;
  persistPackOrder: boolean;
  clearPackOrder: boolean;
  persistAutoSort: boolean;
  clearAutoSort: boolean;
  persistFavoriteOrder: boolean;
  clearFavoriteOrder: boolean;
  persistAutoSortFavorites: boolean;
  clearAutoSortFavorites: boolean;
}

const initialState: StickerPreferencesState = {
  packOrder: [],
  autoSortEnabled: false,
  favoriteStickerOrder: [],
  autoSortFavoritesEnabled: false,
  hydrationStatus: 'idle',
};

// --- Generic keyed-order helpers ---
// Both StickerPackOrderItem and FavoriteStickerOrderItem are structurally
// { id: string; lastUsedOn: number }, differing only in the ID field name.
// These helpers operate on either via a `key` parameter.
// TS interfaces lack implicit index signatures, so we cast to Record inside
// the helpers when accessing dynamic keys.

function normalizeKeyedOrderItems<T extends { lastUsedOn: number }>(
  items: T[],
  key: keyof T & string,
): { items: T[]; changed: boolean } {
  const deduped = new Map<string, T>();
  let changed = false;

  for (const item of items) {
    const id = (item as unknown as Record<string, string>)[key];
    const truncated = Math.trunc(item.lastUsedOn);
    if (truncated !== item.lastUsedOn || deduped.has(id)) {
      changed = true;
    }
    deduped.set(id, { ...item, [key]: id, lastUsedOn: truncated });
  }

  return { items: Array.from(deduped.values()), changed };
}

function isKeyedOrderItem(value: unknown, key: string): boolean {
  if (value == null || typeof value !== 'object') {
    return false;
  }

  const candidate = value as Record<string, unknown>;
  return (
    typeof candidate[key] === 'string' &&
    (candidate[key] as string).length > 0 &&
    typeof candidate.lastUsedOn === 'number' &&
    Number.isFinite(candidate.lastUsedOn)
  );
}

function normalizeKeyedOrderValue<T extends { lastUsedOn: number }>(
  savedOrder: unknown,
  key: keyof T & string,
  makeItem: (id: string) => T,
): { order: T[]; persist: boolean; clear: boolean } {
  if (savedOrder == null) {
    return { order: [], persist: false, clear: false };
  }

  if (!Array.isArray(savedOrder)) {
    return { order: [], persist: false, clear: true };
  }

  if (savedOrder.length === 0) {
    return { order: [], persist: false, clear: false };
  }

  // Legacy migration: plain string[] (pack order only, but harmless generically)
  if (savedOrder.every((item) => typeof item === 'string')) {
    const deduped = Array.from(new Set(savedOrder));
    return {
      order: deduped.map((id) => makeItem(id)),
      persist: true,
      clear: false,
    };
  }

  if (!savedOrder.every((item) => isKeyedOrderItem(item, key))) {
    return { order: [], persist: false, clear: true };
  }

  const normalized = normalizeKeyedOrderItems(savedOrder as T[], key);
  return {
    order: normalized.items,
    persist: normalized.changed,
    clear: false,
  };
}

function normalizeBooleanValue(saved: unknown): {
  value: boolean;
  persist: boolean;
  clear: boolean;
} {
  if (saved == null) {
    return { value: false, persist: false, clear: false };
  }

  if (typeof saved !== 'boolean') {
    return { value: false, persist: false, clear: true };
  }

  return { value: saved, persist: false, clear: false };
}

function replacePackOrder(state: StickerPreferencesState, packOrder: StickerPackOrderItem[]) {
  state.packOrder = normalizeKeyedOrderItems(packOrder, 'stickerPackId').items;
}

function replaceFavoriteOrder(state: StickerPreferencesState, favoriteOrder: FavoriteStickerOrderItem[]) {
  state.favoriteStickerOrder = normalizeKeyedOrderItems(favoriteOrder, 'stickerId').items;
}

export function hydrateStickerPreferences(
  savedOrder: unknown,
  savedAutoSort: unknown,
  savedFavoriteOrder?: unknown,
  savedAutoSortFavorites?: unknown,
): HydratedStickerPreferences {
  const normalizedOrder = normalizeKeyedOrderValue<StickerPackOrderItem>(savedOrder, 'stickerPackId', (id) => ({
    stickerPackId: id,
    lastUsedOn: 0,
  }));
  const normalizedAutoSort = normalizeBooleanValue(savedAutoSort);
  const normalizedFavoriteOrder = normalizeKeyedOrderValue<FavoriteStickerOrderItem>(
    savedFavoriteOrder,
    'stickerId',
    (id) => ({ stickerId: id, lastUsedOn: 0 }),
  );
  const normalizedAutoSortFavorites = normalizeBooleanValue(savedAutoSortFavorites);

  return {
    state: {
      packOrder: normalizedOrder.order,
      autoSortEnabled: normalizedAutoSort.value,
      favoriteStickerOrder: normalizedFavoriteOrder.order,
      autoSortFavoritesEnabled: normalizedAutoSortFavorites.value,
      hydrationStatus: 'kv',
    },
    persistPackOrder: normalizedOrder.persist,
    clearPackOrder: normalizedOrder.clear,
    persistAutoSort: normalizedAutoSort.persist,
    clearAutoSort: normalizedAutoSort.clear,
    persistFavoriteOrder: normalizedFavoriteOrder.persist,
    clearFavoriteOrder: normalizedFavoriteOrder.clear,
    persistAutoSortFavorites: normalizedAutoSortFavorites.persist,
    clearAutoSortFavorites: normalizedAutoSortFavorites.clear,
  };
}

export function sortStickerPacksByPreference<T extends { id: string }>(
  packs: T[],
  packOrder: StickerPackOrderItem[],
): T[] {
  return sortByKeyedOrder(packs, packOrder, 'stickerPackId');
}

export function sortFavoriteStickersByPreference<T extends { id: string }>(
  stickers: T[],
  favoriteOrder: FavoriteStickerOrderItem[],
): T[] {
  return sortByKeyedOrder(stickers, favoriteOrder, 'stickerId');
}

function sortByKeyedOrder<T extends { id: string }, O extends { lastUsedOn: number }>(
  items: T[],
  order: O[],
  key: keyof O & string,
): T[] {
  const originalIndex = new Map(items.map((item, index) => [item.id, index]));
  const lastUsedById = new Map(order.map((item) => [item[key] as string, item.lastUsedOn as number]));

  return [...items].sort((a, b) => {
    const lastUsedA = lastUsedById.get(a.id);
    const lastUsedB = lastUsedById.get(b.id);

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
      action: PayloadAction<
        Pick<
          StickerPreferencesState,
          'packOrder' | 'autoSortEnabled' | 'favoriteStickerOrder' | 'autoSortFavoritesEnabled'
        >
      >,
    ) {
      replacePackOrder(state, action.payload.packOrder);
      state.autoSortEnabled = action.payload.autoSortEnabled;
      replaceFavoriteOrder(state, action.payload.favoriteStickerOrder);
      state.autoSortFavoritesEnabled = action.payload.autoSortFavoritesEnabled;
      state.hydrationStatus = 'kv';
    },
    setAutoSortEnabled(state, action: PayloadAction<boolean>) {
      state.autoSortEnabled = action.payload;
    },
    setAutoSortFavoritesEnabled(state, action: PayloadAction<boolean>) {
      state.autoSortFavoritesEnabled = action.payload;
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
    upsertFavoriteStickerOrderItem(state, action: PayloadAction<FavoriteStickerOrderItem>) {
      const existing = state.favoriteStickerOrder.find((item) => item.stickerId === action.payload.stickerId);
      if (existing) {
        existing.lastUsedOn = Math.trunc(action.payload.lastUsedOn);
      } else {
        state.favoriteStickerOrder.push({
          stickerId: action.payload.stickerId,
          lastUsedOn: Math.trunc(action.payload.lastUsedOn),
        });
      }
      replaceFavoriteOrder(state, state.favoriteStickerOrder);
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
  setAutoSortFavoritesEnabled,
  upsertStickerPackOrderItem,
  upsertFavoriteStickerOrderItem,
} = stickerPreferencesSlice.actions;

export const selectStickerPreferences = (state: RootState) => state.stickerPreferences;
export const selectStickerPackOrder = (state: RootState) => state.stickerPreferences.packOrder;
export const selectStickerAutoSortEnabled = (state: RootState) => state.stickerPreferences.autoSortEnabled;
export const selectStickerHydrationStatus = (state: RootState) => state.stickerPreferences.hydrationStatus;
export const selectFavoritesAutoSortEnabled = (state: RootState) => state.stickerPreferences.autoSortFavoritesEnabled;
export const selectFavoritesOrder = (state: RootState) => state.stickerPreferences.favoriteStickerOrder;
export const selectStickerPackOrderRankMap = (state: RootState) => {
  const sortedOrder = [...state.stickerPreferences.packOrder].sort((a, b) => b.lastUsedOn - a.lastUsedOn);
  return new Map(sortedOrder.map((item, index) => [item.stickerPackId, index]));
};

export default stickerPreferencesSlice.reducer;
