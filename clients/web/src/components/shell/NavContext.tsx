"use client";

import { usePathname, useRouter } from "next/navigation";
import { createContext, useCallback, useContext, useEffect, useMemo, useRef } from "react";
import { focusElement, focusables, initialFocusTarget } from "@/lib/spatial";
import { TABS, type TabId, isTabRoot, normalizePath, tabForPath, tabRoot } from "@/lib/tabs";

interface Nav {
  pathname: string;
  tab: TabId;
  isRoot: boolean;
  /** Pop the current tab's stack; at a tab root, move focus to the tab bar. */
  back: () => void;
  /** Switch to a tab by id, or by relative offset (wraps). Re-selecting the active tab pops to its root. */
  switchTab: (target: TabId | number) => void;
  focusSearch: () => void;
  focusTabBar: () => void;
  /** LT / RT: page between Library collections / Community sections. */
  page: (dir: 1 | -1) => void;
  /** Where a tab link should point (each tab remembers its own stack). */
  hrefFor: (id: TabId) => string;
}

const Ctx = createContext<Nav | null>(null);

const RAW_FOCUSABLE = 'a[href],button,input,select,textarea,[tabindex]:not([tabindex="-1"])';

function currentMode(): string {
  return document.documentElement.dataset.input ?? "mouse";
}

export function NavProvider({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const pathname = normalizePath(usePathname() || "/");
  const tab = tabForPath(pathname);
  const pathRef = useRef(pathname);
  pathRef.current = pathname;

  // Per-tab navigation stacks, a linear in-app history and remembered focus.
  const stacks = useRef<Record<TabId, string[]>>({ store: [], library: [], community: [], profile: [] });
  /** In-app history; `kind` records how each entry was reached. */
  const history = useRef<{ path: string; kind: "link" | "tab" }[]>([]);
  const nextKind = useRef<"link" | "tab">("link");
  const focusMemory = useRef(new Map<string, number>());
  const pendingSearch = useRef(false);

  const focusTabBar = useCallback(() => {
    const el = [...document.querySelectorAll<HTMLElement>("[data-tabbar] [aria-current='page']")].find(
      (e) => e.getBoundingClientRect().width > 0,
    );
    if (el) focusElement(el);
  }, []);

  const focusSearch = useCallback(() => {
    const input = [...document.querySelectorAll<HTMLInputElement>("input[data-search]")].find(
      (e) => e.getBoundingClientRect().width > 0,
    );
    if (input) {
      focusElement(input);
      input.select();
    } else {
      pendingSearch.current = true;
      router.push("/store/");
    }
  }, [router]);

  // Record every navigation, then move focus into the new page when the user is
  // driving with keyboard / gamepad (restoring the old focus when going back).
  useEffect(() => {
    const t = tabForPath(pathname);
    const st = stacks.current[t];
    if (isTabRoot(pathname)) stacks.current[t] = [pathname];
    else {
      const i = st.indexOf(pathname);
      if (i >= 0) st.length = i + 1;
      else st.push(pathname);
    }
    const h = history.current;
    let wentBack = false;
    if (h.length >= 2 && h[h.length - 2].path === pathname) {
      h.pop();
      wentBack = true;
    } else if (h[h.length - 1]?.path !== pathname) h.push({ path: pathname, kind: nextKind.current });
    nextKind.current = "link";

    const mode = currentMode();
    if (mode !== "keyboard" && mode !== "gamepad") {
      pendingSearch.current = false;
      return;
    }
    let raf2 = 0;
    const raf1 = requestAnimationFrame(() => {
      raf2 = requestAnimationFrame(() => {
        if (pendingSearch.current) {
          pendingSearch.current = false;
          const input = document.querySelector<HTMLInputElement>("input[data-search]");
          if (input) return focusElement(input);
        }
        const main = document.getElementById("main");
        const remembered = focusMemory.current.get(pathname);
        if (wentBack && main && remembered !== undefined) {
          const el = main.querySelectorAll<HTMLElement>(RAW_FOCUSABLE)[remembered];
          if (el && focusables(el.parentElement ?? main).includes(el)) return focusElement(el, false);
        }
        const target = initialFocusTarget();
        if (target) focusElement(target, false);
      });
    });
    return () => {
      cancelAnimationFrame(raf1);
      cancelAnimationFrame(raf2);
    };
  }, [pathname]);

  // Remember which element in <main> was focused on each page.
  useEffect(() => {
    const onFocusIn = (e: FocusEvent) => {
      const main = document.getElementById("main");
      const el = e.target as HTMLElement | null;
      if (!main || !el || !main.contains(el)) return;
      const idx = [...main.querySelectorAll(RAW_FOCUSABLE)].indexOf(el);
      if (idx >= 0) focusMemory.current.set(pathRef.current, idx);
    };
    document.addEventListener("focusin", onFocusIn);
    return () => document.removeEventListener("focusin", onFocusIn);
  }, []);

  const back = useCallback(() => {
    const p = pathRef.current;
    const t = tabForPath(p);
    if (isTabRoot(p)) return focusTabBar();
    const h = history.current;
    // Opened via a link → return to wherever it was opened from.
    if (h.length >= 2 && h[h.length - 1].kind === "link") return router.back();
    // Reached by switching tabs (restored from the tab's stack) → pop that stack.
    const st = stacks.current[t];
    router.push(st.length > 1 ? st[st.length - 2] : tabRoot(t));
  }, [router, focusTabBar]);

  const switchTab = useCallback(
    (target: TabId | number) => {
      const p = pathRef.current;
      const cur = tabForPath(p);
      const idx = TABS.findIndex((x) => x.id === cur);
      const next = typeof target === "number" ? TABS[(idx + target + TABS.length) % TABS.length].id : target;
      if (next === cur) {
        if (!isTabRoot(p)) {
          nextKind.current = "tab";
          router.push(tabRoot(cur));
        }
        else {
          window.scrollTo({ top: 0, behavior: "smooth" });
          const mode = currentMode();
          if (mode === "keyboard" || mode === "gamepad") {
            const el = initialFocusTarget();
            if (el) focusElement(el);
          }
        }
        return;
      }
      const st = stacks.current[next];
      nextKind.current = "tab";
      router.push(st[st.length - 1] ?? tabRoot(next));
    },
    [router],
  );

  const page = useCallback((dir: 1 | -1) => {
    window.dispatchEvent(new CustomEvent("ns:page", { detail: dir }));
  }, []);

  const hrefFor = useCallback(
    (id: TabId) => {
      if (id === tab) return tabRoot(id);
      const st = stacks.current[id];
      return st[st.length - 1] ?? tabRoot(id);
    },
    [tab],
  );

  const value = useMemo(
    () => ({ pathname, tab, isRoot: isTabRoot(pathname), back, switchTab, focusSearch, focusTabBar, page, hrefFor }),
    [pathname, tab, back, switchTab, focusSearch, focusTabBar, page, hrefFor],
  );
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useNav(): Nav {
  const ctx = useContext(Ctx);
  if (!ctx) throw new Error("useNav outside NavProvider");
  return ctx;
}

/** Subscribe to LT / RT paging events. */
export function usePaging(handler: (dir: 1 | -1) => void) {
  const ref = useRef(handler);
  ref.current = handler;
  useEffect(() => {
    const on = (e: Event) => ref.current((e as CustomEvent<1 | -1>).detail);
    window.addEventListener("ns:page", on);
    return () => window.removeEventListener("ns:page", on);
  }, []);
}
