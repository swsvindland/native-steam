// Spatial navigation: move focus to the nearest focusable element in a
// direction using bounding rects, then keep it scrolled into view (including
// inside horizontal shelves, with ~1 card of lookahead).

export type Direction = "up" | "down" | "left" | "right";

const FOCUSABLE = [
  "a[href]",
  "button:not([disabled])",
  "input:not([disabled]):not([type=hidden])",
  "select:not([disabled])",
  "textarea:not([disabled])",
  '[tabindex]:not([tabindex="-1"])',
].join(",");

function isVisible(el: HTMLElement, r: DOMRect): boolean {
  if (r.width < 1 || r.height < 1) return false;
  if (el.closest("[inert],[aria-hidden='true'],[data-nav-skip]")) return false;
  const style = getComputedStyle(el);
  return style.visibility !== "hidden" && style.display !== "none";
}

export function focusables(root: ParentNode = document): HTMLElement[] {
  return [...root.querySelectorAll<HTMLElement>(FOCUSABLE)].filter((el) =>
    isVisible(el, el.getBoundingClientRect()),
  );
}

interface Box {
  left: number;
  right: number;
  top: number;
  bottom: number;
}

/** The element's rect with any current scale transform removed, so a focused
 *  (scaled-up) card doesn't overlap its neighbours when we measure. */
function layoutBox(el: HTMLElement): Box {
  const r = el.getBoundingClientRect();
  const t = getComputedStyle(el).transform;
  if (t && t !== "none") {
    const m = new DOMMatrixReadOnly(t);
    const sx = Math.hypot(m.a, m.b) || 1;
    const sy = Math.hypot(m.c, m.d) || 1;
    if (Math.abs(sx - 1) > 0.001 || Math.abs(sy - 1) > 0.001) {
      const cx = r.left + r.width / 2;
      const cy = r.top + r.height / 2;
      const w = r.width / sx;
      const h = r.height / sy;
      return { left: cx - w / 2, right: cx + w / 2, top: cy - h / 2, bottom: cy + h / 2 };
    }
  }
  return { left: r.left, right: r.right, top: r.top, bottom: r.bottom };
}

function gap(aStart: number, aEnd: number, bStart: number, bEnd: number): number {
  if (bEnd < aStart) return aStart - bEnd;
  if (bStart > aEnd) return bStart - aEnd;
  return 0;
}

/** Clip a box to the visible area of its scrolling ancestors (e.g. a carousel
 *  slide that is still animating into view) so we measure what the user sees. */
function visibleBox(el: HTMLElement): Box {
  const b = layoutBox(el);
  for (let p = el.parentElement; p && p !== document.body; p = p.parentElement) {
    if (!isScrollable(p, "x")) continue;
    const r = p.getBoundingClientRect();
    const left = Math.max(b.left, r.left);
    const right = Math.min(b.right, r.right);
    if (right - left > 8) {
      b.left = left;
      b.right = right;
    }
  }
  return b;
}

export function findNext(from: HTMLElement, dir: Direction, scope?: ParentNode): HTMLElement | null {
  const a = visibleBox(from);
  const tol = 2;
  let best: HTMLElement | null = null;
  let bestScore = Infinity;
  for (const el of focusables(scope ?? document)) {
    if (el === from || el.contains(from) || from.contains(el)) continue;
    const b = layoutBox(el);
    let primary: number;
    let secondary: number;
    let align: number;
    switch (dir) {
      case "right":
        if (b.left < a.right - tol) continue;
        primary = b.left - a.right;
        secondary = gap(a.top, a.bottom, b.top, b.bottom);
        align = Math.abs(b.top - a.top);
        break;
      case "left":
        if (b.right > a.left + tol) continue;
        primary = a.left - b.right;
        secondary = gap(a.top, a.bottom, b.top, b.bottom);
        align = Math.abs(b.top - a.top);
        break;
      case "down":
        if (b.top < a.bottom - tol) continue;
        primary = b.top - a.bottom;
        secondary = gap(a.left, a.right, b.left, b.right);
        align = Math.abs(b.left - a.left);
        break;
      case "up":
        if (b.bottom > a.top + tol) continue;
        primary = a.top - b.bottom;
        secondary = gap(a.left, a.right, b.left, b.right);
        align = Math.abs(b.left - a.left);
        break;
    }
    // Left / right stay within the current row. Up / down strongly prefer
    // elements overlapping on the cross axis; among those, the one whose
    // leading edge lines up with ours wins.
    if ((dir === "left" || dir === "right") && secondary > 0) continue;
    const score = Math.max(0, primary) + secondary * 3 + (secondary > 0 ? 400 : 0) + align * 0.15;
    if (score < bestScore) {
      bestScore = score;
      best = el;
    }
  }
  return best;
}

function isScrollable(el: HTMLElement, axis: "x" | "y"): boolean {
  const style = getComputedStyle(el);
  const overflow = axis === "x" ? style.overflowX : style.overflowY;
  if (overflow !== "auto" && overflow !== "scroll") return false;
  return axis === "x" ? el.scrollWidth > el.clientWidth + 1 : el.scrollHeight > el.clientHeight + 1;
}

function insets(): { top: number; bottom: number } {
  const root = getComputedStyle(document.documentElement);
  const top = parseFloat(root.getPropertyValue("--nav-inset-top")) || 0;
  const bottom = parseFloat(root.getPropertyValue("--nav-inset-bottom")) || 0;
  return { top, bottom };
}

/** Scroll every scrollable ancestor (and the page) so `el` is fully visible. */
export function reveal(el: HTMLElement, smooth = true): void {
  const behavior: ScrollBehavior = smooth && !matchMedia("(prefers-reduced-motion: reduce)").matches ? "smooth" : "auto";
  const box = layoutBox(el);

  // Horizontal shelves / carousels.
  for (let p = el.parentElement; p && p !== document.body; p = p.parentElement) {
    if (isScrollable(p, "x")) {
      const pr = p.getBoundingClientRect();
      const width = box.right - box.left;
      const padStart = parseFloat(getComputedStyle(p).scrollPaddingInlineStart) || 0;
      if (p.dataset.reveal === "snap" || width > pr.width * 0.66) {
        // Full-width pages (hero carousel): align exactly to the item.
        const target = p.scrollLeft + (box.left - pr.left) - padStart;
        if (Math.abs(target - p.scrollLeft) > 1) p.scrollTo({ left: target, behavior });
      } else {
        const look = Math.min(width * 0.6, 160); // ~a card of lookahead
        let delta = 0;
        if (box.right + look > pr.right) delta = box.right + look - pr.right;
        if (box.left - look - padStart < pr.left) delta = box.left - look - padStart - pr.left;
        if (box.left - padStart >= pr.left && box.right + look <= pr.right) delta = 0;
        if (delta) p.scrollBy({ left: delta, behavior });
      }
    }
    if (isScrollable(p, "y")) {
      const pr = p.getBoundingClientRect();
      const margin = 16;
      if (box.top - margin < pr.top) p.scrollBy({ top: box.top - margin - pr.top, behavior });
      else if (box.bottom + margin > pr.bottom) p.scrollBy({ top: box.bottom + margin - pr.bottom, behavior });
    }
  }

  // The page itself (skip things living in fixed/sticky chrome).
  if (el.closest("[data-nav-fixed]")) return;
  const { top, bottom } = insets();
  const viewTop = top + 16;
  const viewBottom = window.innerHeight - bottom - 16;
  const h = box.bottom - box.top;
  let delta = 0;
  if (h > viewBottom - viewTop || box.top < viewTop) delta = box.top - viewTop - 24;
  else if (box.bottom > viewBottom) delta = box.bottom - viewBottom + 24;
  if (delta) window.scrollBy({ top: delta, behavior });
}

export function focusElement(el: HTMLElement, smooth = true): void {
  el.focus({ preventScroll: true });
  reveal(el, smooth);
}

/** First item to focus when entering a page with keyboard/gamepad. */
export function initialFocusTarget(): HTMLElement | null {
  const main = document.getElementById("main");
  if (!main) return null;
  const preferred = [...main.querySelectorAll<HTMLElement>("[data-autofocus]")].find((el) =>
    isVisible(el, el.getBoundingClientRect()),
  );
  if (preferred) return preferred;
  return focusables(main).find((el) => el.tagName !== "INPUT") ?? null;
}
