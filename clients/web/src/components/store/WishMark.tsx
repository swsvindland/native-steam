"use client";

import { Heart } from "lucide-react";
import { useUserState } from "../shell/UserState";

/** Small "on your wishlist" marker that reacts to the X / Wishlist action. */
export function WishMark({ appId, inline = false }: { appId: number; inline?: boolean }) {
  const { wishlist } = useUserState();
  if (!wishlist.has(appId)) return null;
  return (
    <span className={`wishmark${inline ? " wishmark--inline" : ""}`} title="On your wishlist">
      <Heart size={12} fill="currentColor" />
    </span>
  );
}
