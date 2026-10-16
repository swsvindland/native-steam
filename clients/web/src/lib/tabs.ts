export type TabId = "store" | "library" | "community" | "profile";

export interface TabDef {
  id: TabId;
  root: string;
  /** Label shown in the nav. The persona tab uses the user's name instead. */
  label: string;
}

export const TABS: TabDef[] = [
  { id: "store", root: "/store/", label: "Store" },
  { id: "library", root: "/library/", label: "Library" },
  { id: "community", root: "/community/", label: "Community" },
  { id: "profile", root: "/profile/", label: "Profile" },
];

export function normalizePath(pathname: string): string {
  return pathname.endsWith("/") ? pathname : `${pathname}/`;
}

export function tabForPath(pathname: string): TabId {
  const p = normalizePath(pathname);
  if (p.startsWith("/library/")) return "library";
  if (p.startsWith("/community/")) return "community";
  if (p.startsWith("/profile/")) return "profile";
  return "store";
}

export function isTabRoot(pathname: string): boolean {
  const p = normalizePath(pathname);
  return p === "/" || TABS.some((t) => t.root === p);
}

export function tabRoot(id: TabId): string {
  return TABS.find((t) => t.id === id)!.root;
}
