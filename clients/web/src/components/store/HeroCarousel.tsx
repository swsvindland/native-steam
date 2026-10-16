"use client";

import Link from "next/link";
import { ChevronLeft, ChevronRight } from "lucide-react";
import { useCallback, useEffect, useRef, useState } from "react";
import type { StoreItem } from "@/lib/types";
import { Art } from "../ui/Art";
import { PlatformIcons, PriceBlock, ReviewLabel } from "../ui/bits";
import { WishMark } from "./WishMark";

const AUTO_ADVANCE_MS = 6000;

/**
 * FEATURED & RECOMMENDED. A scroll-snap carousel so touch can swipe-page it;
 * mouse gets arrows + dots; keyboard / gamepad focus moves slide to slide.
 * Auto-advances every 6 s, paused while hovered or while focus is inside.
 */
export function HeroCarousel({ items }: { items: StoreItem[] }) {
  const track = useRef<HTMLDivElement>(null);
  const [index, setIndex] = useState(0);
  const [hovered, setHovered] = useState(false);
  const [focused, setFocused] = useState(false);
  const paused = hovered || focused;

  const go = useCallback(
    (i: number, smooth = true) => {
      const el = track.current;
      if (!el) return;
      const n = items.length;
      const next = ((i % n) + n) % n;
      const slide = el.children[next] as HTMLElement | undefined;
      if (!slide) return;
      el.scrollTo({ left: slide.offsetLeft - el.offsetLeft - (parseFloat(getComputedStyle(el).paddingLeft) || 0), behavior: smooth ? "smooth" : "auto" });
    },
    [items.length],
  );

  // Derive the active slide from the scroll position (works for swipes too).
  const onScroll = () => {
    const el = track.current;
    if (!el) return;
    const slide = el.children[0] as HTMLElement | undefined;
    const w = slide ? slide.offsetWidth + (parseFloat(getComputedStyle(el).columnGap) || 0) : el.clientWidth;
    const i = Math.round(el.scrollLeft / w);
    if (i !== index) setIndex(Math.max(0, Math.min(items.length - 1, i)));
  };

  useEffect(() => {
    // No auto-advance while hovered / focused, or for reduced-motion users.
    if (paused || matchMedia("(prefers-reduced-motion: reduce)").matches) return;
    const id = window.setTimeout(() => {
      if (document.visibilityState === "visible") go(index + 1);
    }, AUTO_ADVANCE_MS);
    return () => window.clearTimeout(id);
  }, [index, paused, go]);

  return (
    <div
      className="hero"
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      onFocus={() => setFocused(true)}
      onBlur={(e) => {
        if (!e.currentTarget.contains(e.relatedTarget as Node | null)) setFocused(false);
      }}
      aria-roledescription="carousel"
      aria-label="Featured and recommended"
    >
      <div className="hero__ambient" aria-hidden="true">
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img key={items[index]?.appId} src={items[index]?.images.background ?? items[index]?.images.capsule} alt="" decoding="async" />
      </div>
      <div className="hero__track" ref={track} onScroll={onScroll} data-reveal="snap">
        {items.map((item, i) => (
          <Link
            key={item.appId}
            href={`/store/app/${item.appId}/`}
            className="hero__slide card"
            aria-roledescription="slide"
            aria-label={`${i + 1} of ${items.length}: ${item.name}`}
            data-autofocus={i === 0 ? "" : undefined}
            data-x="wishlist"
            data-id={item.appId}
            data-name={item.name}
          >
            <span className="hero__capsule">
              <Art className="art--capsule" src={item.images.capsule} label={item.name} eager={i < 2} />
              <span className="hero__overlay">
                <span className="hero__overlay-name">{item.name}</span>
                <PriceBlock price={item.price} releaseDate={item.releaseDate} comingSoon={item.comingSoon} size="sm" />
              </span>
            </span>
            <span className="hero__panel">
              <span className="hero__name">{item.name}</span>
              <span className="hero__shots">
                {item.screenshots.slice(0, 4).map((s) => (
                  <Art key={s.thumbnail} className="art--16x9" src={s.thumbnail} eager={i < 2} />
                ))}
              </span>
              <span className="hero__review">
                <span className="hero__review-caption">Overall user reviews</span>
                <ReviewLabel review={item.review} />
              </span>
              <span className="hero__tags">
                {item.genres.slice(0, 4).map((g) => (
                  <span key={g} className="tag">
                    {g}
                  </span>
                ))}
              </span>
              <span className="hero__bottom">
                <PlatformIcons platforms={item.platforms} />
                <PriceBlock price={item.price} releaseDate={item.releaseDate} comingSoon={item.comingSoon} />
              </span>
            </span>
            <WishMark appId={item.appId} />
          </Link>
        ))}
      </div>
      <button type="button" className="hero__arrow hero__arrow--prev" tabIndex={-1} data-nav-skip aria-label="Previous" onClick={() => go(index - 1)}>
        <ChevronLeft size={28} />
      </button>
      <button type="button" className="hero__arrow hero__arrow--next" tabIndex={-1} data-nav-skip aria-label="Next" onClick={() => go(index + 1)}>
        <ChevronRight size={28} />
      </button>
      <div className="hero__dots" data-nav-skip>
        {items.map((item, i) => (
          <button
            key={item.appId}
            type="button"
            tabIndex={-1}
            className="hero__dot"
            aria-current={i === index ? "true" : undefined}
            aria-label={`Show ${item.name}`}
            onClick={() => go(i)}
          />
        ))}
      </div>
    </div>
  );
}
