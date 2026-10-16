"use client";

import { createContext, useCallback, useContext, useMemo, useRef, useState } from "react";

/** The "X" secondary action a focused element supports (`data-x` attribute). */
export type SecondaryKind = "favorite" | "wishlist" | "like";

interface UserState {
  favorites: Set<number>;
  wishlist: Set<number>;
  cart: Set<number>;
  liked: Set<string>;
  toggleFavorite: (appId: number, name?: string) => void;
  toggleWishlist: (appId: number, name?: string) => void;
  toggleLike: (id: string) => void;
  addToCart: (appId: number, name?: string) => void;
  /** Dispatches an `X` press for an element carrying `data-x`, `data-id`, `data-name`. */
  secondary: (el: HTMLElement) => boolean;
  toast: { id: number; text: string } | null;
  showToast: (text: string) => void;
}

const Ctx = createContext<UserState | null>(null);

function toggled<T>(set: Set<T>, v: T): Set<T> {
  const next = new Set(set);
  if (next.has(v)) next.delete(v);
  else next.add(v);
  return next;
}

/** Local, in-memory user actions. Everything here is purely visual. */
export function UserStateProvider({
  initialFavorites,
  children,
}: {
  initialFavorites: number[];
  children: React.ReactNode;
}) {
  const [favorites, setFavorites] = useState(() => new Set(initialFavorites));
  const [wishlist, setWishlist] = useState(() => new Set<number>());
  const [cart, setCart] = useState(() => new Set<number>());
  const [liked, setLiked] = useState(() => new Set<string>());
  const [toast, setToast] = useState<{ id: number; text: string } | null>(null);
  const toastTimer = useRef<ReturnType<typeof setTimeout> | null>(null);
  const favRef = useRef(favorites);
  favRef.current = favorites;
  const wishRef = useRef(wishlist);
  wishRef.current = wishlist;

  const showToast = useCallback((text: string) => {
    if (toastTimer.current) clearTimeout(toastTimer.current);
    setToast({ id: Date.now(), text });
    toastTimer.current = setTimeout(() => setToast(null), 2200);
  }, []);

  const toggleFavorite = useCallback(
    (appId: number, name?: string) => {
      const was = favRef.current.has(appId);
      setFavorites((s) => toggled(s, appId));
      showToast(was ? `Removed ${name ?? "game"} from Favorites` : `Added ${name ?? "game"} to Favorites`);
    },
    [showToast],
  );
  const toggleWishlist = useCallback(
    (appId: number, name?: string) => {
      const was = wishRef.current.has(appId);
      setWishlist((s) => toggled(s, appId));
      showToast(was ? `Removed ${name ?? "game"} from your wishlist` : `Added ${name ?? "game"} to your wishlist`);
    },
    [showToast],
  );
  const toggleLike = useCallback((id: string) => setLiked((s) => toggled(s, id)), []);
  const addToCart = useCallback(
    (appId: number, name?: string) => {
      setCart((s) => new Set(s).add(appId));
      showToast(`${name ?? "Game"} added to cart · demo only, nothing is purchased`);
    },
    [showToast],
  );

  const secondary = useCallback(
    (el: HTMLElement) => {
      const host = el.closest<HTMLElement>("[data-x]");
      if (!host) return false;
      const kind = host.dataset.x as SecondaryKind;
      const id = host.dataset.id ?? "";
      const name = host.dataset.name;
      if (kind === "favorite") toggleFavorite(Number(id), name);
      else if (kind === "wishlist") toggleWishlist(Number(id), name);
      else if (kind === "like") toggleLike(id);
      else return false;
      return true;
    },
    [toggleFavorite, toggleWishlist, toggleLike],
  );

  const value = useMemo(
    () => ({
      favorites,
      wishlist,
      cart,
      liked,
      toggleFavorite,
      toggleWishlist,
      toggleLike,
      addToCart,
      secondary,
      toast,
      showToast,
    }),
    [favorites, wishlist, cart, liked, toggleFavorite, toggleWishlist, toggleLike, addToCart, secondary, toast, showToast],
  );
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useUserState(): UserState {
  const ctx = useContext(Ctx);
  if (!ctx) throw new Error("useUserState outside UserStateProvider");
  return ctx;
}
