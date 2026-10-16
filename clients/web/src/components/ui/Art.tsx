"use client";

import { useEffect, useRef, useState } from "react";

/**
 * Steam CDN artwork: lazy-loaded plain <img> over a surface-coloured
 * placeholder that shows the game name while loading or if the image fails.
 * The wrapper fixes the aspect ratio; the image is aspect-fill + clipped.
 */
export function Art({
  src,
  alt = "",
  label,
  className = "",
  eager = false,
  priority = false,
  fallbackSrc,
  position,
}: {
  src: string | null | undefined;
  alt?: string;
  /** Text drawn on the placeholder (usually the game name). */
  label?: string;
  className?: string;
  eager?: boolean;
  /** The page's hero (LCP) image: load eagerly at high fetch priority. */
  priority?: boolean;
  /** Tried once if `src` fails (e.g. hero → capsule). */
  fallbackSrc?: string | null;
  /** object-position override, e.g. "center top". */
  position?: string;
}) {
  const [current, setCurrent] = useState(src || fallbackSrc || null);
  const [state, setState] = useState<"loading" | "loaded" | "error">(current ? "loading" : "error");
  const img = useRef<HTMLImageElement>(null);

  useEffect(() => {
    const next = src || fallbackSrc || null;
    setCurrent(next);
    setState(next ? "loading" : "error");
  }, [src, fallbackSrc]);

  // Images that finished before hydration never fire onLoad in React.
  useEffect(() => {
    const el = img.current;
    if (el && el.complete) setState(el.naturalWidth > 0 ? "loaded" : "error");
  }, [current]);

  const onError = () => {
    if (fallbackSrc && current !== fallbackSrc) {
      setCurrent(fallbackSrc);
      setState("loading");
    } else setState("error");
  };

  return (
    <span className={`art ${className}`} data-state={state}>
      {state !== "loaded" && label ? <span className="art__label">{label}</span> : null}
      {current && state !== "error" ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img
          ref={img}
          src={current}
          alt={alt}
          loading={eager || priority ? "eager" : "lazy"}
          fetchPriority={priority ? "high" : undefined}
          decoding={priority ? "sync" : "async"}
          draggable={false}
          onLoad={() => setState("loaded")}
          onError={onError}
          style={position ? { objectPosition: position } : undefined}
        />
      ) : null}
    </span>
  );
}
