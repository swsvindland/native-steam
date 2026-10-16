"use client";

import Link from "next/link";
import { ChevronLeft, LayoutGrid, Search, ShoppingBag, Users } from "lucide-react";
import { useEffect, useState } from "react";
import { TABS, type TabId } from "@/lib/tabs";
import { Controller } from "./Controller";
import { InputProvider, useInput } from "./InputContext";
import { NavProvider, useNav } from "./NavContext";
import { UserStateProvider, useUserState } from "./UserState";
import { PadButton, PadBumper } from "./PadGlyph";
import { LightboxProvider } from "../ui/Lightbox";

export interface ShellUser {
  personaName: string;
  avatarUrl: string;
  friendsOnline: number;
  friendsInGame: number;
}

export function Shell({
  user,
  initialFavorites,
  children,
}: {
  user: ShellUser;
  initialFavorites: number[];
  children: React.ReactNode;
}) {
  return (
    <InputProvider>
      <UserStateProvider initialFavorites={initialFavorites}>
        <NavProvider>
          <LightboxProvider>
            <TopNav user={user} />
            <main id="main" className="main">
              {children}
            </main>
            <TabBar user={user} />
            <HintsBar />
            <Toast />
            <Controller />
          </LightboxProvider>
        </NavProvider>
      </UserStateProvider>
    </InputProvider>
  );
}

function tabLabel(id: TabId, persona: string): string {
  return id === "profile" ? persona : TABS.find((t) => t.id === id)!.label;
}

function usePadVisible(): boolean {
  const { mode, gamepadConnected } = useInput();
  return mode === "gamepad" || gamepadConnected;
}

function TopNav({ user }: { user: ShellUser }) {
  const nav = useNav();
  const pad = usePadVisible();
  return (
    <header className="topnav" data-nav-fixed>
      <div className="topnav__inner">
        <button
          type="button"
          className="topnav__back iconbtn"
          aria-label="Back"
          disabled={nav.isRoot}
          onClick={nav.back}
          tabIndex={nav.isRoot ? -1 : 0}
        >
          <ChevronLeft size={20} />
        </button>
        <Link href="/store/" className="wordmark" aria-label="Steam (concept) — Store" tabIndex={-1}>
          STEAM
        </Link>
        <nav className="topnav__tabs" data-tabbar aria-label="Main">
          {pad && <PadBumper side="L" />}
          {TABS.map((t) => (
            <Link
              key={t.id}
              href={nav.hrefFor(t.id)}
              className="topnav__tab"
              aria-current={nav.tab === t.id ? "page" : undefined}
              onClick={(e) => {
                e.preventDefault();
                nav.switchTab(t.id);
              }}
            >
              {tabLabel(t.id, user.personaName)}
            </Link>
          ))}
          {pad && <PadBumper side="R" />}
        </nav>
        <div className="topnav__end">
          <button type="button" className="iconbtn" aria-label="Search" onClick={nav.focusSearch}>
            <Search size={18} />
          </button>
          <Link
            href="/community/#friends"
            className="topnav__friends"
            aria-label={`Friends: ${user.friendsOnline} online, ${user.friendsInGame} in-game`}
            title={`${user.friendsOnline} online · ${user.friendsInGame} in-game`}
          >
            <Users size={17} />
            <span className="topnav__friends-count">{user.friendsOnline}</span>
            <span className="topnav__friends-label">online</span>
          </Link>
          <Link href="/profile/" className="topnav__me" aria-label={`${user.personaName} — profile`}>
            {/* eslint-disable-next-line @next/next/no-img-element */}
            <img src={user.avatarUrl} alt="" className="topnav__avatar" width={30} height={30} />
            <span className="topnav__me-name">{user.personaName}</span>
          </Link>
        </div>
      </div>
    </header>
  );
}

const TAB_ICONS: Record<Exclude<TabId, "profile">, React.ComponentType<{ size?: number; strokeWidth?: number }>> = {
  store: ShoppingBag,
  library: LayoutGrid,
  community: Users,
};

function TabBar({ user }: { user: ShellUser }) {
  const nav = useNav();
  const pad = usePadVisible();
  return (
    <nav className="tabbar" data-nav-fixed data-tabbar aria-label="Main">
      {pad && <PadBumper side="L" />}
      {TABS.map((t) => {
        const Icon = t.id === "profile" ? null : TAB_ICONS[t.id];
        const current = nav.tab === t.id;
        return (
          <Link
            key={t.id}
            href={nav.hrefFor(t.id)}
            className="tabbar__item"
            aria-current={current ? "page" : undefined}
            onClick={(e) => {
              e.preventDefault();
              nav.switchTab(t.id);
            }}
          >
            {Icon ? (
              <Icon size={23} strokeWidth={current ? 2.2 : 1.8} />
            ) : (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={user.avatarUrl} alt="" className="tabbar__avatar" width={26} height={26} />
            )}
            <span className="tabbar__label">{tabLabel(t.id, user.personaName)}</span>
          </Link>
        );
      })}
      {pad && <PadBumper side="R" />}
    </nav>
  );
}

function useFocusedSecondary(): { kind: string; id: string } | null {
  const [state, setState] = useState<{ kind: string; id: string } | null>(null);
  useEffect(() => {
    const update = () => {
      const el = document.activeElement as HTMLElement | null;
      const host = el?.closest<HTMLElement>("[data-x]");
      setState(host ? { kind: host.dataset.x ?? "", id: host.dataset.id ?? "" } : null);
    };
    document.addEventListener("focusin", update);
    document.addEventListener("focusout", update);
    return () => {
      document.removeEventListener("focusin", update);
      document.removeEventListener("focusout", update);
    };
  }, []);
  return state;
}

function HintsBar() {
  const { mode } = useInput();
  const nav = useNav();
  const user = useUserState();
  const x = useFocusedSecondary();
  if (mode !== "gamepad") return null;

  let xLabel: string | null = null;
  if (x?.kind === "favorite") xLabel = user.favorites.has(Number(x.id)) ? "Unfavorite" : "Favorite";
  else if (x?.kind === "wishlist") xLabel = user.wishlist.has(Number(x.id)) ? "Unwishlist" : "Wishlist";
  else if (x?.kind === "like") xLabel = user.liked.has(x.id) ? "Unlike" : "Like";
  const canSearch = nav.tab === "store" || nav.tab === "library";
  const pageLabel = nav.tab === "library" && nav.isRoot ? "Collection" : nav.tab === "community" ? "Section" : null;

  return (
    <div className="hints" data-nav-fixed aria-hidden="true">
      <div className="hints__inner">
        <span className="hints__brand">STEAM</span>
        <span className="hints__spacer" />
        <span className="hint">
          <PadButton b="A" /> Select
        </span>
        <span className="hint">
          <PadButton b="B" /> Back
        </span>
        {xLabel && (
          <span className="hint">
            <PadButton b="X" /> {xLabel}
          </span>
        )}
        {canSearch && (
          <span className="hint">
            <PadButton b="Y" /> Search
          </span>
        )}
        {pageLabel && (
          <span className="hint hint--page">
            <PadBumper side="L" trigger />
            <PadBumper side="R" trigger /> {pageLabel}
          </span>
        )}
        <span className="hint hint--tabs">
          <PadBumper side="L" />
          <PadBumper side="R" /> Switch tab
        </span>
      </div>
    </div>
  );
}

function Toast() {
  const { toast } = useUserState();
  return (
    <div className="toast-region" role="status" aria-live="polite">
      {toast && (
        <div key={toast.id} className="toast">
          {toast.text}
        </div>
      )}
    </div>
  );
}
