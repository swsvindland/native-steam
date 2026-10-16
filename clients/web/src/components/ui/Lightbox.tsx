"use client";

import { ChevronLeft, ChevronRight, X } from "lucide-react";
import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from "react";
import { focusElement } from "@/lib/spatial";

interface LightboxApi {
  open: (urls: string[], index: number, caption?: string) => void;
}

const Ctx = createContext<LightboxApi | null>(null);

/**
 * Full-screen screenshot viewer. While open it is the only navigable surface
 * (`data-overlay` scopes spatial navigation); B / Esc closes it and focus
 * returns to the thumbnail that opened it.
 */
export function LightboxProvider({ children }: { children: React.ReactNode }) {
  const [state, setState] = useState<{ urls: string[]; index: number; caption?: string } | null>(null);
  const opener = useRef<HTMLElement | null>(null);
  const closeBtn = useRef<HTMLButtonElement>(null);

  const open = useCallback((urls: string[], index: number, caption?: string) => {
    opener.current = document.activeElement as HTMLElement | null;
    setState({ urls, index, caption });
  }, []);

  const close = useCallback(() => {
    setState(null);
    const el = opener.current;
    if (el) requestAnimationFrame(() => focusElement(el, false));
  }, []);

  const step = useCallback((d: number) => {
    setState((s) => (s ? { ...s, index: (s.index + d + s.urls.length) % s.urls.length } : s));
  }, []);

  useEffect(() => {
    if (!state) return;
    closeBtn.current?.focus({ preventScroll: true });
    const prevOverflow = document.documentElement.style.overflow;
    document.documentElement.style.overflow = "hidden";
    return () => {
      document.documentElement.style.overflow = prevOverflow;
    };
  }, [state !== null]); // eslint-disable-line react-hooks/exhaustive-deps

  const api = useMemo(() => ({ open }), [open]);

  return (
    <Ctx.Provider value={api}>
      {children}
      {state ? (
        <div
          className="lightbox"
          role="dialog"
          aria-modal="true"
          aria-label="Screenshot viewer"
          data-overlay
          onKeyDown={(e) => {
            if (e.key === "Escape" || e.key === "Backspace") {
              e.preventDefault();
              close();
            } else if (e.key === "ArrowLeft" || e.key === "ArrowRight") {
              e.preventDefault();
              step(e.key === "ArrowLeft" ? -1 : 1);
            }
          }}
          onClick={(e) => {
            if (e.target === e.currentTarget) close();
          }}
        >
          <button type="button" className="lightbox__close iconbtn" ref={closeBtn} onClick={close} aria-label="Close" data-dismiss>
            <X size={22} />
          </button>
          {state.urls.length > 1 ? (
            <button type="button" className="lightbox__nav lightbox__nav--prev iconbtn" data-dir="left" onClick={() => step(-1)} aria-label="Previous screenshot">
              <ChevronLeft size={30} />
            </button>
          ) : null}
          {/* eslint-disable-next-line @next/next/no-img-element */}
          <img className="lightbox__img" src={state.urls[state.index]} alt={state.caption ?? "Screenshot"} />
          {state.urls.length > 1 ? (
            <button type="button" className="lightbox__nav lightbox__nav--next iconbtn" data-dir="right" onClick={() => step(1)} aria-label="Next screenshot">
              <ChevronRight size={30} />
            </button>
          ) : null}
          <div className="lightbox__caption">
            {state.caption ? <span>{state.caption}</span> : null}
            <span>
              {state.index + 1} / {state.urls.length}
            </span>
          </div>
        </div>
      ) : null}
    </Ctx.Provider>
  );
}

export function useLightbox(): LightboxApi {
  const ctx = useContext(Ctx);
  if (!ctx) throw new Error("useLightbox outside LightboxProvider");
  return ctx;
}

/** A focusable thumbnail that opens the lightbox. */
export function ShotButton({
  urls,
  index,
  caption,
  className = "",
  children,
}: {
  urls: string[];
  index: number;
  caption?: string;
  className?: string;
  children: React.ReactNode;
}) {
  const { open } = useLightbox();
  return (
    <button type="button" className={`shot card ${className}`} onClick={() => open(urls, index, caption)} aria-label={`Open screenshot${caption ? ` of ${caption}` : ""}`}>
      {children}
    </button>
  );
}
