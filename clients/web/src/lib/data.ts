// Build-time data access. Only server components import this module, so the
// 600 KB snapshot never ships in a client bundle — pages pass the slices they
// need down as props. (`node:fs` here makes an accidental client import fail
// loudly at build time.)
import { readFileSync } from "node:fs";
import { join } from "node:path";
import type { ChartEntry, Friend, LibraryGame, Snapshot, StoreItem } from "./types";

let cached: Snapshot | null = null;

export function getSnapshot(): Snapshot {
  if (!cached) {
    const file = join(process.cwd(), "src/generated/snapshot.json");
    cached = JSON.parse(readFileSync(file, "utf8")) as Snapshot;
  }
  return cached;
}

/** Every distinct store item across the store sections, first occurrence wins. */
export function storeItems(): Map<number, StoreItem> {
  const { store } = getSnapshot();
  const map = new Map<number, StoreItem>();
  for (const list of [store.featured, store.specials, store.topSellers, store.newReleases, store.comingSoon]) {
    for (const item of list) if (!map.has(item.appId)) map.set(item.appId, item);
  }
  return map;
}

/** App ids that get a static store page: store items + Most Played chart entries. */
export function storeAppIds(): number[] {
  const ids = new Set(storeItems().keys());
  for (const entry of getSnapshot().store.mostPlayed) ids.add(entry.appId);
  return [...ids];
}

export type StorePageModel =
  | { kind: "item"; item: StoreItem; chart: ChartEntry | null }
  | { kind: "chart"; chart: ChartEntry };

export function storePage(appId: number): StorePageModel | null {
  const item = storeItems().get(appId);
  const chart = getSnapshot().store.mostPlayed.find((c) => c.appId === appId) ?? null;
  if (item) return { kind: "item", item, chart };
  if (chart) return { kind: "chart", chart };
  return null;
}

export function libraryGame(appId: number): LibraryGame | undefined {
  return getSnapshot().library.games.find((g) => g.appId === appId);
}

export function libraryIds(): Set<number> {
  return new Set(getSnapshot().library.games.map((g) => g.appId));
}

export function friendsById(): Map<string, Friend> {
  return new Map(getSnapshot().friends.map((f) => [f.steamId, f]));
}

const statusOrder: Record<string, number> = { inGame: 0, online: 1, away: 2, offline: 3 };

export function sortedFriends(): Friend[] {
  return [...getSnapshot().friends].sort(
    (a, b) => (statusOrder[a.status] ?? 9) - (statusOrder[b.status] ?? 9),
  );
}

/** Where a game link should go: the library page if owned, else the store page if we have one. */
export function gameHref(appId: number): string | null {
  if (libraryIds().has(appId)) return `/library/game/${appId}/`;
  if (storeAppIds().includes(appId)) return `/store/app/${appId}/`;
  return null;
}
