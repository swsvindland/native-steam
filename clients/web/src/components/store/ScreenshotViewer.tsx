"use client";

import { useRef, useState } from "react";
import type { Screenshot } from "@/lib/types";
import { Art } from "../ui/Art";
import { useLightbox } from "../ui/Lightbox";

/** Store page media: big screenshot + snap-scrolling thumbnail strip. */
export function ScreenshotViewer({ shots, name }: { shots: Screenshot[]; name: string }) {
  const [active, setActive] = useState(0);
  const strip = useRef<HTMLDivElement>(null);
  const lightbox = useLightbox();
  if (shots.length === 0) return null;
  const current = shots[Math.min(active, shots.length - 1)];
  const urls = shots.map((s) => s.full);

  return (
    <div className="viewer">
      <button type="button" className="viewer__main card" onClick={() => lightbox.open(urls, active, name)} aria-label="Open screenshot" data-autofocus>
        <Art className="art--16x9" src={current.full} fallbackSrc={current.thumbnail} label={name} eager />
      </button>
      <div className="viewer__strip" ref={strip} role="list">
        {shots.map((s, i) => (
          <button
            key={s.thumbnail}
            type="button"
            role="listitem"
            className="viewer__thumb card"
            aria-current={i === active ? "true" : undefined}
            aria-label={`Screenshot ${i + 1}`}
            onClick={() => setActive(i)}
            onFocus={() => setActive(i)}
          >
            <Art className="art--16x9" src={s.thumbnail} />
          </button>
        ))}
      </div>
    </div>
  );
}
