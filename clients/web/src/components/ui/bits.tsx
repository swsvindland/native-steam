import Link from "next/link";
import { ChevronRight, Gamepad2 } from "lucide-react";
import type { Platforms, Price, ReviewSummary } from "@/lib/types";

/** Price block: discount badge + struck original + final, or just the final label. */
export function PriceBlock({
  price,
  releaseDate,
  comingSoon,
  size = "md",
}: {
  price: Price | null;
  releaseDate?: string | null;
  comingSoon?: boolean;
  size?: "sm" | "md" | "lg";
}) {
  if (!price) {
    return (
      <span className={`price price--${size} price--soon`}>
        <span className="price__final">{comingSoon && releaseDate ? releaseDate : "Coming soon"}</span>
      </span>
    );
  }
  if (price.discountLabel) {
    return (
      <span className={`price price--${size} price--discounted`}>
        <span className="price__badge">{price.discountLabel}</span>
        <span className="price__stack">
          <span className="price__original">{price.initialLabel}</span>
          <span className="price__final">{price.finalLabel}</span>
        </span>
      </span>
    );
  }
  return (
    <span className={`price price--${size}`}>
      <span className="price__final">{price.finalLabel}</span>
    </span>
  );
}

export function SectionHeader({
  title,
  count,
  href,
  hrefLabel = "See all",
  children,
  id,
}: {
  title: string;
  count?: number;
  href?: string;
  hrefLabel?: string;
  children?: React.ReactNode;
  id?: string;
}) {
  return (
    <div className="section-header">
      <h2 className="section-title" id={id}>
        {title}
        {count !== undefined ? <span className="section-count"> ({count})</span> : null}
      </h2>
      {children}
      {href ? (
        <Link href={href} className="see-all" tabIndex={-1}>
          {hrefLabel} <ChevronRight size={14} />
        </Link>
      ) : null}
    </div>
  );
}

export function reviewTone(review: ReviewSummary | null): string {
  if (!review) return "none";
  // Steam shows "N user reviews" (too few to score) in a neutral colour.
  if (review.total < 10) return "none";
  return review.tone;
}

export function ReviewLabel({ review, withCount = false }: { review: ReviewSummary | null; withCount?: boolean }) {
  if (!review) return <span className="review review--none">No user reviews</span>;
  return (
    <span className={`review review--${reviewTone(review)}`}>
      {review.label}
      {withCount ? <span className="review__count"> ({review.totalLabel})</span> : null}
    </span>
  );
}

export function ToneDot({ review }: { review: ReviewSummary | null }) {
  return <span className={`tone-dot tone-dot--${reviewTone(review)}`} title={review?.label ?? "No reviews"} />;
}

function WindowsIcon() {
  return (
    <svg viewBox="0 0 16 16" width="14" height="14" aria-hidden="true">
      <path fill="currentColor" d="M1 2.6 6.6 1.8v5.5H1zM7.4 1.7 15 .6v6.7H7.4zM1 8.1h5.6v5.5L1 12.8zM7.4 8.1H15v6.7l-7.6-1.1z" />
    </svg>
  );
}
function MacIcon() {
  return (
    <svg viewBox="0 0 16 16" width="14" height="14" aria-hidden="true">
      <rect x="1.5" y="2.5" width="13" height="8.5" rx="1.2" fill="none" stroke="currentColor" strokeWidth="1.4" />
      <path fill="currentColor" d="M5.5 13h5l.6 1.5H4.9z" />
    </svg>
  );
}
function LinuxIcon() {
  // Generic terminal-prompt glyph (SteamOS + Linux).
  return (
    <svg viewBox="0 0 16 16" width="14" height="14" aria-hidden="true">
      <rect x="1.2" y="2.2" width="13.6" height="11.6" rx="2" fill="none" stroke="currentColor" strokeWidth="1.4" />
      <path d="m4 6 2.2 2L4 10M8 10.5h4" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}

export function PlatformIcons({ platforms }: { platforms: Platforms }) {
  return (
    <span className="platforms" aria-label="Platforms">
      {platforms.windows && (
        <span title="Windows">
          <WindowsIcon />
        </span>
      )}
      {platforms.mac && (
        <span title="macOS">
          <MacIcon />
        </span>
      )}
      {platforms.linux && (
        <span title="SteamOS + Linux">
          <LinuxIcon />
        </span>
      )}
    </span>
  );
}

export function ControllerBadge({ support }: { support: string | null }) {
  if (!support) return null;
  return (
    <span className={`controller-badge controller-badge--${support}`}>
      <Gamepad2 size={16} />
      {support === "full" ? "Full Controller Support" : "Partial Controller Support"}
    </span>
  );
}

export function ProgressBar({ value, className = "" }: { value: number; className?: string }) {
  const pct = Math.max(0, Math.min(1, value)) * 100;
  return (
    <span className={`progress ${className}`} role="progressbar" aria-valuenow={Math.round(pct)} aria-valuemin={0} aria-valuemax={100}>
      <span className="progress__fill" style={{ width: `${pct}%` }} />
    </span>
  );
}

export function LevelRing({ level, color, size = "md" }: { level: number; color: string; size?: "sm" | "md" | "lg" }) {
  return (
    <span className={`level-ring level-ring--${size}`} style={{ borderColor: color }} title={`Steam Level ${level}`}>
      {level}
    </span>
  );
}

export function LiveDot() {
  return <span className="live-dot" aria-hidden="true" />;
}

/** Compact-only large title used at the top of each tab root. */
export function PageTitle({ children, trailing }: { children: React.ReactNode; trailing?: React.ReactNode }) {
  return (
    <div className="page-title compact-only">
      <h1>{children}</h1>
      {trailing}
    </div>
  );
}
