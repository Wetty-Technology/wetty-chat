import { useMemo } from 'react';
import type { ReactionReactor } from '@/api/messages';
import { MAX_REACTION_HEAD_TABS } from '@/constants/emojiAndStickers';

export interface ReactionGroup {
  emoji: string;
  reactors: ReactionReactor[];
}

export interface GroupedUser extends ReactionReactor {
  emojis: string[];
  firstReactIndex: number;
}

export interface ReactionCategory {
  key: string; // 'all', 'more', or specific emoji
  label: string; // Display name or emoji
  count: number;
  users: GroupedUser[];
}

export interface ReactionGroupingResult {
  categories: ReactionCategory[];
}

export function useReactionGrouping(groups: ReactionGroup[]): ReactionGroupingResult {
  return useMemo(() => {
    if (!groups || groups.length === 0) return { categories: [] };

    const groupsWithIndex = groups.map((g, originalIndex) => ({ g, originalIndex }));

    groupsWithIndex.sort((a, b) => {
      const countDiff = b.g.reactors.length - a.g.reactors.length;
      if (countDiff !== 0) return countDiff;
      return a.originalIndex - b.originalIndex;
    });

    const topGroupsUnsorted = groupsWithIndex.slice(0, MAX_REACTION_HEAD_TABS).map((item) => item.g);
    const moreGroups = groupsWithIndex.slice(MAX_REACTION_HEAD_TABS).map((item) => item.g);

    const topGroups = topGroupsUnsorted.sort((a, b) => {
      const countDiff = b.reactors.length - a.reactors.length;
      if (countDiff !== 0) return countDiff;
      return a.emoji < b.emoji ? -1 : a.emoji > b.emoji ? 1 : 0;
    });

    const categories: ReactionCategory[] = [];

    const allUsersMap = new Map<number, GroupedUser>();
    let globalIndex = 0;

    groups.forEach((g) => {
      g.reactors.forEach((r) => {
        const index = r.sortIndex ?? globalIndex++;
        if (!allUsersMap.has(r.uid)) {
          allUsersMap.set(r.uid, {
            ...r,
            emojis: [g.emoji],
            firstReactIndex: index,
          });
        } else {
          const existing = allUsersMap.get(r.uid)!;
          existing.emojis.push(g.emoji);
          if (index < existing.firstReactIndex) {
            existing.firstReactIndex = index;
          }
        }
      });
    });

    const allUsersSorted = Array.from(allUsersMap.values()).sort((a, b) => a.firstReactIndex - b.firstReactIndex);

    categories.push({
      key: 'all',
      label: 'All',
      count: allUsersMap.size,
      users: allUsersSorted,
    });

    topGroups.forEach((g) => {
      const users: GroupedUser[] = g.reactors.map((r, i) => ({
        ...r,
        emojis: [g.emoji],
        firstReactIndex: r.sortIndex ?? i,
      }));

      categories.push({
        key: g.emoji,
        label: g.emoji,
        count: users.length,
        users,
      });
    });

    // --- Process 'More' category ---
    if (moreGroups.length > 0) {
      const moreUsers: GroupedUser[] = [];
      moreGroups.forEach((g) => {
        g.reactors.forEach((r, i) => {
          moreUsers.push({
            ...r,
            emojis: [g.emoji],
            firstReactIndex: r.sortIndex ?? i,
          });
        });
      });

      categories.push({
        key: 'more',
        label: 'More',
        count: moreUsers.length,
        users: moreUsers,
      });
    }

    return { categories };
  }, [groups]);
}
