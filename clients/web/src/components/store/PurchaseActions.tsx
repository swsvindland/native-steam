"use client";

import Link from "next/link";
import { Check, Heart, Play, ShoppingCart } from "lucide-react";
import { useUserState } from "../shell/UserState";

/** Add to Cart + Wishlist. Purely visual — there is no purchase flow. */
export function PurchaseActions({
  appId,
  name,
  owned,
  free,
  comingSoon,
}: {
  appId: number;
  name: string;
  owned: boolean;
  free: boolean;
  comingSoon: boolean;
}) {
  const { wishlist, toggleWishlist, cart, addToCart, showToast } = useUserState();
  const wished = wishlist.has(appId);
  const inCart = cart.has(appId);
  return (
    <span className="purchase__actions">
      {owned ? (
        <Link href={`/library/game/${appId}/`} className="btn btn--play btn--lg">
          <Play size={18} fill="currentColor" /> In Library
        </Link>
      ) : comingSoon ? null : free ? (
        <button type="button" className="btn btn--install btn--lg" onClick={() => showToast(`${name} · demo only, nothing is installed`)}>
          Play Game
        </button>
      ) : (
        <button type="button" className="btn btn--install btn--lg" onClick={() => addToCart(appId, name)} data-x="wishlist" data-id={appId} data-name={name}>
          {inCart ? <Check size={18} /> : <ShoppingCart size={18} />}
          {inCart ? "In Cart" : "Add to Cart"}
        </button>
      )}
      <button
        type="button"
        className={`btn btn--secondary btn--lg${wished ? " is-on" : ""}`}
        aria-pressed={wished}
        onClick={() => toggleWishlist(appId, name)}
      >
        <Heart size={17} fill={wished ? "currentColor" : "none"} />
        {wished ? "On Wishlist" : comingSoon ? "Add to your Wishlist" : "Wishlist"}
      </button>
    </span>
  );
}
