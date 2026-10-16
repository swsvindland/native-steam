"use client";

import { ChevronLeft, ChevronRight } from "lucide-react";
import { useCallback, useEffect, useRef, useState } from "react";

/**
 * Horizontally scrolling, snap-aligned row of cards. Touch swipes natively;
 * mouse users get edge arrows on hover; keyboard / gamepad focus movement
 * auto-scrolls it via spatial navigation's `reveal()`.
 */
export function Shelf({
  children,
  className = "",
  label,
}: {
  children: React.ReactNode;
  className?: string;
  label?: string;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const [edges, setEdges] = useState({ start: true, end: false });

  const update = useCallback(() => {
    const el = ref.current;
    if (!el) return;
    setEdges({ start: el.scrollLeft < 4, end: el.scrollLeft + el.clientWidth >= el.scrollWidth - 4 });
  }, []);

  useEffect(() => {
    update();
    const el = ref.current;
    if (!el) return;
    const ro = new ResizeObserver(update);
    ro.observe(el);
    return () => ro.disconnect();
  }, [update]);

  const page = (dir: 1 | -1) => {
    const el = ref.current;
    if (!el) return;
    el.scrollBy({ left: dir * el.clientWidth * 0.85, behavior: "smooth" });
  };

  return (
    <div className={`shelf ${className}`} data-start={edges.start} data-end={edges.end}>
      <div className="shelf__track" ref={ref} onScroll={update} role="list" aria-label={label}>
        {children}
      </div>
      <button type="button" className="shelf__arrow shelf__arrow--prev" tabIndex={-1} data-nav-skip aria-label="Scroll left" onClick={() => page(-1)}>
        <ChevronLeft size={22} />
      </button>
      <button type="button" className="shelf__arrow shelf__arrow--next" tabIndex={-1} data-nav-skip aria-label="Scroll right" onClick={() => page(1)}>
        <ChevronRight size={22} />
      </button>
    </div>
  );
}
