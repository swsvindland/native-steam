/** Xbox-style face button glyph (A / B / X / Y). */
export function PadButton({ b }: { b: "A" | "B" | "X" | "Y" }) {
  return (
    <span className={`padbtn padbtn--${b.toLowerCase()}`} aria-hidden="true">
      {b}
    </span>
  );
}

/** LB / RB (or LT / RT with `trigger`) glyph. */
export function PadBumper({ side, trigger = false }: { side: "L" | "R"; trigger?: boolean }) {
  return (
    <span className={`padbumper${trigger ? " padbumper--trigger" : ""}`} aria-hidden="true" data-nav-skip>
      {side}
      {trigger ? "T" : "B"}
    </span>
  );
}
