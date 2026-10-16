"use client";

import { ChevronLeft } from "lucide-react";
import { useNav } from "../shell/NavContext";

/** Floating back button for detail pages on compact widths (the top nav has one on regular). */
export function BackButton() {
  const { back } = useNav();
  return (
    <button type="button" className="float-back compact-only" onClick={back} aria-label="Back">
      <ChevronLeft size={24} />
    </button>
  );
}
